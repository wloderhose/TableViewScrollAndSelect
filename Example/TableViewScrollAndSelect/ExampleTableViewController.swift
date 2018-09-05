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
    private var sectionCount = 1
    private var rowCount = 100
    private var cells = [[Int]]()
    private var scrollingSpeed: UITableViewScrollAndSelectController.ScrollingSpeed = .moderate
    private var scrollAndSelectController: UITableViewScrollAndSelectController!
    private var refreshButton: UIBarButtonItem!
    private var deleteButton: UIBarButtonItem!
    
    // MARK: - Memory Management
    deinit {
        scrollAndSelectController?.invalidate()
        scrollAndSelectController = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        reloadCells()
        navigationItem.leftBarButtonItem = self.editButtonItem
        scrollAndSelectController = UITableViewScrollAndSelectController(tableView: tableView, scrollingSpeed: scrollingSpeed)
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
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        scrollAndSelectController.enabled = editing
        updateNavBarForSelection()
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
        
        let selectionCount = tableView.indexPathsForSelectedRows?.count ?? 0
        navigationItem.title = "\(selectionCount) selected"
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
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 50.0
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "showSettings" {
            self.setEditing(false, animated: true)
            let settingsVC = segue.destination as! ExampleSettingsViewController
            settingsVC.delegate = self
        }
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
    
    func settingsDidChangeScrollingSpeed(speed: UITableViewScrollAndSelectController.ScrollingSpeed) {
        
        scrollingSpeed = speed
        scrollAndSelectController.updateSpeed(speed)
    }
    
    func settingsCurrentRowCount() -> Int {
        return rowCount
    }
    
    func settingsCurrentSectionCount() -> Int {
        return sectionCount
    }
    
    func settingsCurrentScrollingSpeed() -> UITableViewScrollAndSelectController.ScrollingSpeed {
        return scrollingSpeed
    }
    
}





