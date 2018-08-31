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
    private var exampleCells: [Int] = Array(1...100)
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

        scrollAndSelectController = UITableViewScrollAndSelectController(tableView: tableView, scrollingSpeed: .slow)

        refreshButton = UIBarButtonItem(title: "Refresh", style: .plain, target: self, action: #selector(refreshTapped))
        deleteButton = UIBarButtonItem(title: "Delete", style: .plain, target: self, action: #selector(deleteTapped))
        
        navigationItem.leftBarButtonItem = refreshButton
        navigationItem.rightBarButtonItem = self.editButtonItem
        
        updateNavBarForSelection()
    }
    
    override func viewDidLayoutSubviews() {
        scrollAndSelectController.configure()
    }
    
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        
        scrollAndSelectController.enabled = editing
        navigationItem.leftBarButtonItem = editing ? deleteButton : refreshButton
        updateNavBarForSelection()
    }
    
    // MARK: - Button Actions
    @objc private func refreshTapped() {
        
        exampleCells = Array(1...100)
        updateNavBarForSelection()
        tableView.reloadData()
        tableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: .bottom, animated: false)
    }
    
    @objc private func deleteTapped() {
        
        if let indexPaths = tableView.indexPathsForSelectedRows {
            
            tableView.beginUpdates()
            
            // Delete rows from table view
            tableView.deleteRows(at: indexPaths, with: .left)
            
            // WATCH OUT - indexPathsForSelectedRows isn't sorted by indexPath! It's sorted by order of selection from user.
            // Let's sort them in reverse order so that we can delete them while enumerating
            let reverseSortedIndexPaths: [IndexPath] = indexPaths.sorted(by: { (indexPath1, indexPath2) -> Bool in
                return indexPath1.row > indexPath2.row
            })
            
            // Delete rows from array
            for i in reverseSortedIndexPaths {
                exampleCells.remove(at: i.row)
            }
            
            tableView.endUpdates()
        }
    }
    
    private func updateNavBarForSelection() {
        
        let selectionCount = tableView.indexPathsForSelectedRows?.count ?? 0
        navigationItem.title = "\(selectionCount) selected"
        deleteButton.isEnabled = selectionCount > 0
    }

    // MARK: - Table view data source / delegate
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return exampleCells.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "exampleCell", for: indexPath)
        cell.textLabel?.text = "Example Cell \(exampleCells[indexPath.row])"
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
}





