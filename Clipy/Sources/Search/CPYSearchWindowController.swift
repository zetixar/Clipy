//
//  CPYSearchWindowController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Copilot on 2025/12/14.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import RealmSwift

// MARK: - Search Result Item
struct SearchResultItem {
    let type: SearchResultType
    let clip: CPYClip?
    let snippet: CPYSnippet?
    let displayTitle: String
    let displayContent: String
    let matchScore: Float
    
    enum SearchResultType {
        case clip
        case snippet
    }
    
    init(clip: CPYClip, score: Float = 1.0) {
        self.type = .clip
        self.clip = clip
        self.snippet = nil
        self.displayTitle = clip.title.isEmpty ? "Clipboard Item" : clip.title
        self.displayContent = clip.title
        self.matchScore = score
    }
    
    init(snippet: CPYSnippet, score: Float = 1.0) {
        self.type = .snippet
        self.clip = nil
        self.snippet = snippet
        self.displayTitle = snippet.title
        self.displayContent = snippet.content
        self.matchScore = score
    }
}

final class CPYSearchWindowController: NSWindowController {

    // MARK: - Properties
    static let sharedController = CPYSearchWindowController()
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var statusLabel: NSTextField!
    
    private var searchResults: [SearchResultItem] = []
    private var selectedIndex: Int = -1
    private let realm = try! Realm()
    private var searchService: SearchService!
    
    // MARK: - Initialize
    private override init(window: NSWindow?) {
        super.init(window: window)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    convenience init() {
        self.init(windowNibName: "CPYSearchWindowController")
        setup()
    }
    
    private func setup() {
        searchService = SearchService()
    }
    
    override func windowDidLoad() {
        super.windowDidLoad()
        setupWindow()
        setupTableView()
        setupSearchField()
        updateStatusLabel()
    }
    
    // MARK: - Window Setup
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "Clipy Search"
        window.setContentSize(NSSize(width: 600, height: 400))
        window.center()
        window.level = .floating
        window.hidesOnDeactivate = true
        window.animationBehavior = .alertPanel
        
        // Make window respond to escape key
        window.standardWindowButton(.closeButton)?.keyEquivalent = "\u{1b}"
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.backgroundColor = .controlBackgroundColor
        
        // Enable keyboard navigation
        tableView.allowsEmptySelection = false
    }
    
    private func setupSearchField() {
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.placeholderString = L10n.searchClipboardHistoryAndSnippets
        searchField.focusRingType = .none
    }
    
    private func updateStatusLabel() {
        let clipCount = realm.objects(CPYClip.self).count
        let snippetCount = realm.objects(CPYSnippet.self).filter("enable == true").count
        statusLabel.stringValue = "\(clipCount) clips, \(snippetCount) snippets available"
    }
    
    // MARK: - Public Methods
    func showSearchWindow() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        
        // Focus search field and select all text
        searchField.becomeFirstResponder()
        searchField.selectText(nil)
        
        // Show all items initially
        performSearch(query: "")
    }
    
    func hideSearchWindow() {
        window?.orderOut(nil)
    }
    
    // MARK: - Search Actions
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        performSearch(query: sender.stringValue)
    }
    
    private func performSearch(query: String) {
        searchResults = searchService.search(query: query)
        tableView.reloadData()
        
        // Select first item if available
        if !searchResults.isEmpty {
            selectedIndex = 0
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        } else {
            selectedIndex = -1
        }
        
        // Update status
        if query.isEmpty {
            statusLabel.stringValue = "Showing all items"
        } else {
            statusLabel.stringValue = "Found \(searchResults.count) results for '\(query)'"
        }
    }
    
    // MARK: - Table View Actions
    @objc private func tableViewDoubleClicked(_ sender: NSTableView) {
        selectCurrentItem()
    }
    
    private func selectCurrentItem() {
        guard selectedIndex >= 0 && selectedIndex < searchResults.count else { return }
        
        let item = searchResults[selectedIndex]
        
        switch item.type {
        case .clip:
            if let clip = item.clip {
                pasteClip(clip)
            }
        case .snippet:
            if let snippet = item.snippet {
                pasteSnippet(snippet)
            }
        }
        
        hideSearchWindow()
    }
    
    private func pasteClip(_ clip: CPYClip) {
        AppEnvironment.current.pasteService.paste(with: clip)
    }
    
    private func pasteSnippet(_ snippet: CPYSnippet) {
        AppEnvironment.current.pasteService.paste(with: snippet.content)
    }
    
    // MARK: - Keyboard Navigation
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 125: // Down arrow
            moveSelection(direction: 1)
        case 126: // Up arrow
            moveSelection(direction: -1)
        case 36: // Enter
            selectCurrentItem()
        case 53: // Escape
            hideSearchWindow()
        default:
            super.keyDown(with: event)
        }
    }
    
    private func moveSelection(direction: Int) {
        let newIndex = selectedIndex + direction
        if newIndex >= 0 && newIndex < searchResults.count {
            selectedIndex = newIndex
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedIndex)
        }
    }
}

// MARK: - NSTableViewDataSource
extension CPYSearchWindowController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return searchResults.count
    }
}

// MARK: - NSTableViewDelegate
extension CPYSearchWindowController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < searchResults.count else { return nil }
        
        let item = searchResults[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("SearchResultCell")
        
        var cellView = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView
        
        if cellView == nil {
            cellView = NSTableCellView()
            cellView?.identifier = cellIdentifier
            
            // Create text field for title
            let textField = NSTextField()
            textField.isEditable = false
            textField.isBordered = false
            textField.backgroundColor = .clear
            textField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            textField.translatesAutoresizingMaskIntoConstraints = false
            
            // Create text field for content preview
            let detailField = NSTextField()
            detailField.isEditable = false
            detailField.isBordered = false
            detailField.backgroundColor = .clear
            detailField.font = NSFont.systemFont(ofSize: 11)
            detailField.textColor = .secondaryLabelColor
            detailField.translatesAutoresizingMaskIntoConstraints = false
            
            // Create icon image view
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown
            
            cellView?.addSubview(imageView)
            cellView?.addSubview(textField)
            cellView?.addSubview(detailField)
            
            cellView?.textField = textField
            cellView?.imageView = imageView
            
            // Setup constraints
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: cellView!.leadingAnchor, constant: 8),
                imageView.centerYAnchor.constraint(equalTo: cellView!.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 16),
                imageView.heightAnchor.constraint(equalToConstant: 16),
                
                textField.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cellView!.trailingAnchor, constant: -8),
                textField.topAnchor.constraint(equalTo: cellView!.topAnchor, constant: 4),
                
                detailField.leadingAnchor.constraint(equalTo: textField.leadingAnchor),
                detailField.trailingAnchor.constraint(equalTo: textField.trailingAnchor),
                detailField.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 2),
                detailField.bottomAnchor.constraint(lessThanOrEqualTo: cellView!.bottomAnchor, constant: -4)
            ])
        }
        
        // Configure cell content
        cellView?.textField?.stringValue = item.displayTitle
        
        if let detailField = cellView?.subviews.first(where: { $0 is NSTextField && $0 != cellView?.textField }) as? NSTextField {
            let preview = item.displayContent.replacingOccurrences(of: "\n", with: " ").prefix(100)
            detailField.stringValue = String(preview)
        }
        
        // Set icon
        let icon: NSImage
        switch item.type {
        case .clip:
            icon = Asset.iconFolder.image // Using existing icon
        case .snippet:
            icon = Asset.iconText.image // Using existing icon
        }
        icon.isTemplate = true
        cellView?.imageView?.image = icon
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 44.0
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIndex = tableView.selectedRow
    }
}

// MARK: - NSSearchFieldDelegate
extension CPYSearchWindowController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        if let searchField = obj.object as? NSSearchField {
            performSearch(query: searchField.stringValue)
        }
    }
}