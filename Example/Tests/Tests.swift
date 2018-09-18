// https://github.com/Quick/Quick

import Quick
import Nimble
@testable import TableViewScrollAndSelect

class TableOfContentsSpec: QuickSpec {
    
    override func spec() {
        
        describe("a scrollAndSelectController") {
            
            var navigationController: UINavigationController!
            var tableViewController: UITableViewController!
            var scrollAndSelectController: TableViewScrollAndSelectController!
            
            beforeEach {
                navigationController = UIApplication.shared.delegate!.window!!.rootViewController as! UINavigationController
                tableViewController = navigationController.viewControllers[0] as! UITableViewController
                scrollAndSelectController = TableViewScrollAndSelectController(tableView: tableViewController.tableView)
            }
            
            context("is enabled") {
                
                it("is added to view hierarchy") {
                    scrollAndSelectController.enabled = false
                    let subviewCount = tableViewController.tableView.superview!.subviews.count
                    scrollAndSelectController.enabled = true
                    expect(tableViewController.tableView.superview!.subviews.count).to(equal(subviewCount + 1))
                }
                
                describe("tap") {
                    it("has first cell selected") {
                        
                        tableViewController.setEditing(true, animated: false)
                        
                        for indexPath in tableViewController.tableView.indexPathsForSelectedRows ?? [] {
                            tableViewController.tableView.deselectRow(at: indexPath, animated: false)
                        }
                        
                        
                    }
                    
                }
            }
            
            context("is disabled") {
                
                it("is removed from the view hierarchy") {
                    scrollAndSelectController.enabled = true
                    let subviewCount = tableViewController.tableView.superview!.subviews.count
                    scrollAndSelectController.enabled = false
                    expect(tableViewController.tableView.superview!.subviews.count).to(equal(subviewCount - 1))
                }
            }
            
        }
    }
}
