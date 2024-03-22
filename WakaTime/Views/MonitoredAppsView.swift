import AppKit

class MonitoredAppsView: NSView, NSOutlineViewDataSource, NSOutlineViewDelegate {
    struct AppData: Equatable {
        let bundleId: String
        let icon: NSImage
        let name: String
    }

    private var outlineView: NSOutlineView!
    private lazy var apps: [AppData] = {
        var apps = [AppData]()
        let bundleIds = MonitoredApp.allBundleIds.filter { !MonitoredApp.unsupportedAppIds.contains($0) }
        for bundleId in bundleIds {
            if let icon = AppInfo.getIcon(bundleId: bundleId),
               let name = AppInfo.getAppName(bundleId: bundleId) {
                apps.append(AppData(bundleId: bundleId, icon: icon, name: name))
            }
        }
        return apps
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        setupOutlineView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupOutlineView() {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        outlineView = NSOutlineView()
        outlineView.dataSource = self
        outlineView.delegate = self

        scrollView.documentView = outlineView
        addSubview(scrollView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("AppColumn"))
        outlineView.addTableColumn(column)
        outlineView.headerView = nil // Remove header if not needed

        outlineView.outlineTableColumn = column
    }

    func reloadData() {
        outlineView.reloadData()
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        apps.count
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        false
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        apps[index]
    }

    // MARK: NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        50
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let appData = item as? AppData else { return nil }

        let cellView = outlineView.makeView(
          withIdentifier: NSUserInterfaceItemIdentifier("AppCell"),
          owner: self
        ) as? NSTableCellView ?? NSTableCellView()

        // Clear existing subviews to prevent duplication
        cellView.subviews.forEach { $0.removeFromSuperview() }

        let imageView = NSImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = appData.icon
        imageView.image?.size = NSSize(width: 20, height: 20)

        let nameLabel = NSTextField(labelWithString: appData.name)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        let isMonitored = MonitoringManager.isAppMonitored(for: appData.bundleId)
        let switchControl = NSSwitch()
        switchControl.translatesAutoresizingMaskIntoConstraints = false
        switchControl.state = isMonitored ? .on : .off
        switchControl.target = self
        switchControl.action = #selector(switchToggled(_:))
        switchControl.tag = apps.firstIndex(of: appData) ?? -1

        cellView.addSubview(imageView)
        cellView.addSubview(nameLabel)
        cellView.addSubview(switchControl)

        // Determine if the current item is the last in the list
        let isLastItem = apps.last == appData

        if !isLastItem {
            let divider = NSView()
            divider.translatesAutoresizingMaskIntoConstraints = false
            divider.wantsLayer = true
            divider.layer?.backgroundColor = NSColor.separatorColor.cgColor

            cellView.addSubview(divider)

            NSLayoutConstraint.activate([
                divider.heightAnchor.constraint(equalToConstant: 1),
                divider.leadingAnchor.constraint(equalTo: cellView.leadingAnchor),
                divider.trailingAnchor.constraint(equalTo: cellView.trailingAnchor),
                divider.bottomAnchor.constraint(equalTo: cellView.bottomAnchor)
            ])
        }

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 5),
            imageView.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 20),
            imageView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.leadingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: switchControl.leadingAnchor, constant: -10),

            switchControl.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -5),
            switchControl.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
        ])

        return cellView
    }

    @objc func switchToggled(_ sender: NSSwitch) {
        guard sender.tag >= 0 && sender.tag < MonitoredApp.allBundleIds.count else { return }
        let bundleId = apps[sender.tag].bundleId
        MonitoringManager.set(monitoringState: sender.state == .on ? .on : .off, for: bundleId)
    }
}
