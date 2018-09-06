//
//  ExampleTableViewController.swift
//  TableViewScrollAndSelect_Example
//
//  Created by Will Loderhose on 8/31/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import TableViewScrollAndSelect

class ExampleTableViewController: UITableViewController {
    
    // MARK: - Properties
    private var settingsBarButtonItem: UIBarButtonItem!
    private var debugBarButtonItem: UIBarButtonItem!
    
    private var sectionCount = 4
    private var rowCount = 25
    private var cells = [[Int]]()
    private var scrollAndSelectController: TableViewScrollAndSelectController!
    private var refreshButton: UIBarButtonItem!
    private var deleteButton: UIBarButtonItem!
    
    // MARK: - Memory Management
    deinit {
        scrollAndSelectController?.invalidate()
        scrollAndSelectController = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // IMPORTANT
        tableView.allowsMultipleSelectionDuringEditing = true
        
        settingsBarButtonItem = UIBarButtonItem(title: "Settings", style: .plain, target: self, action: #selector(showSettings))
        debugBarButtonItem = UIBarButtonItem(title: "Debug", style: .plain, target: self, action: #selector(toggleDebugMode))
        
        reloadCells()
        navigationItem.leftBarButtonItem = self.editButtonItem
        navigationItem.rightBarButtonItem = settingsBarButtonItem
        scrollAndSelectController = TableViewScrollAndSelectController(tableView: tableView, scrollingSpeed: .moderate)
        updateNavBarForSelection()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        scrollAndSelectController.setNeedsLayout()
        scrollAndSelectController.layoutIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        scrollAndSelectController.layoutIfNeeded()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        scrollAndSelectController.setNeedsLayout()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        scrollAndSelectController.enabled = editing
        navigationItem.rightBarButtonItem = editing ? debugBarButtonItem : settingsBarButtonItem
    }
    
    @objc private func toggleDebugMode(_ sender: Any) {
        scrollAndSelectController.setDebugMode(on: !scrollAndSelectController.isInDebugMode)
    }
    
    @objc private func showSettings(_ sender: Any) {
        
        self.setEditing(false, animated: true)
        let settingsVC = storyboard!.instantiateViewController(withIdentifier: "ExampleSettingsViewController") as! ExampleSettingsViewController
        settingsVC.delegate = self
        navigationController!.pushViewController(settingsVC, animated: true)
    }
    
    private func reloadCells() {
        
        cells.removeAll()
        for section in 0..<sectionCount {
            for row in 0..<rowCount {
                if row == 0 {
                    cells.append([0])
                } else {
                    cells[section].append(row)
                }
            }
        }
        tableView.reloadData()
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .top, animated: false)
    }
    
    private func updateNavBarForSelection() {
        
        if isEditing {
            let selectionCount = tableView.indexPathsForSelectedRows?.count ?? 0
            navigationItem.title = "\(selectionCount) selected"
        } else {
            navigationItem.title = ""
        }
    }

    // MARK: - Table view data source / delegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sectionCount
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rowCount
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "exampleCell", for: indexPath)
        cell.textLabel?.text = "Section \(indexPath.section), Row \(indexPath.row)"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        updateNavBarForSelection()
    }
    
    override func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        updateNavBarForSelection()
    }
    
    // IMPORTANT: Without a correct estimated height, scrolling won't necessarily reach at the exact top/bottom of the table view
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Section \(section)"
    }
}

extension ExampleTableViewController: ExampleSettingsViewDelegate {
    
    func settingsDidChangeSectionCount(count: Int) {
        
        sectionCount = count
        reloadCells()
    }
    
    func settingsDidChangeRowCount(count: Int) {
        
        rowCount = count
        reloadCells()
    }
    
    func settingsDidChangeScrollingSpeed(speed: TableViewScrollAndSelectController.ScrollingSpeed) {
        scrollAndSelectController.scrollingSpeed = speed
    }
    
    func settingsCurrentRowCount() -> Int {
        return rowCount
    }
    
    func settingsCurrentSectionCount() -> Int {
        return sectionCount
    }
    
    func settingsCurrentScrollingSpeed() -> TableViewScrollAndSelectController.ScrollingSpeed {
        return scrollAndSelectController.scrollingSpeed
    }
    
}





