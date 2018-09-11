//
//  TableViewScrollAndSelectController.swift
//  TableViewScrollAndSelect
//
//  Created by Will Loderhose on 8/31/2018.
//  Copyright © 2018 Will Loderhose. All rights reserved.
//

import UIKit

/**
 Allows a `UITableView` to simultaneously select cells and scroll in response to simple pan gestures.
 
 # Important
 * **This class does not replace UITableViewController or create a UITableView.** In order to instantiate a `TableViewScrollAndSelectController`, you must provide it with a `UITableView` to which it will hold a weak reference.
 
 * `TableViewScrollAndSelectController` is **disabled by default.** To enable, set `enabled = true` and be sure that your `UITableView` is part of the app's view hierarchy.
 
 * Because the `TableViewScrollAndSelectController` creates its own `UIView`, **it is necessary to invalidate it when releasing memory**. To do this, you can either call the `invalidate()` method directly, or set `enabled = false`.
 
 * If you are having trouble getting the table view to end scrolling at the correct point, refer to the section about estimated row heights at the end of this description.
 
 # Example Usage
 ```
 class MyTableViewController: UITableViewController {
 
    let scrollAndSelectController: TableViewScrollAndSelectController
 
    // Instantiate the TableViewScrollAndSelectController
    override func viewDidLoad() {
        super.viewDidLoad()
        scrollAndSelectController = TableViewScrollAndSelectController(tableView: tableView)
    }
 
    // Enable/disable when the table view begins/ends editing
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        scrollAndSelectController.enabled = editing
    }
 
    // Invalidate to release memory
    deinit {
        scrollAndSelectController?.invalidate()
    }
 }
 ```
 
 # Debug Mode
 Call `setDebugMode(_:color:)` to turn debug mode on or off or to set a custom debug color, which is green by default. When debug mode is turned on, the `TableViewScrollAndSelectController` will color its touch view and print out event logs to the console.
 
 # More Details
 **Touch view:** `TableViewScrollAndSelectController` adds an invisible `UIView` as the topmost view over your `UITableView`. This touch view and your `UITableView` share the same superview. The touch view receives pan and tap gestures from the user, interprets them, and updates the selection and scrolling of your `UITableView` accordingly.
 * The touch view uses auto layout.
 * The touch view is automatically added or removed from the superview when you change the `enabled` property of the `TableViewScrollAndSelectController`. It is also removed when you call `invalidate()`.
 * By default, the touch view is 60 pixels wide. You can change this by setting the `touchAreaWidth` property to a custom value.
 * By default, the touch view extends to the top, left, and bottom edges of the superview (not safe area). If you would like it to extend only to the safe area, set `touchViewCoversSafeArea = false`.
 
 **Tapping:** Tapping on the touch view simply selects / deselects that cell as it normally would.
 
 **Panning:** During a pan gesture, the first cell encountered determines if we are selecting or deslecting cells. For example, if the first cell in the pan was currently deselected, the `TableViewScrollAndSelectController` will select it and any other cells that are panned over before ending the pan.
 
 **Changing pan direction:** If the pan changes direction, the `TableViewScrollAndSelectController` will switch from selecting to deselecting, or vice versa.
 
 **Automatic scrolling:** If a pan reaches the top or bottom edge of the `UITableView`, the `TableViewScrollAndSelectController` will automatically begin scrolling the table view and will continue selecting / deselecting until the user lifts their finger, pans in the other direction, or reaches the end of the table view.
 
 **Scrolling speed:** You can customize the speed at which the `UITableView` scrolls by changing the `scrollingSpeed` property. By default, it will scroll 20 rows per second.
 
 **Scrolling anchors:** By default, when a pan gesture reaches the top 40 pixels of the table view, the `TableViewScrollAndSelectController` will automatically begin scrolling up. To change this, set the `topScrollingAnchor` property to a custom value. Likewise, by default, when a pan gesture reaches the bottom 40 pixels of the table view, the `TableViewScrollAndSelectController` will automatically begin scrolling down. To change this, set the `bottomScrollingAnchor` property to a custom value. *Note: You must give this a negative value; by default, the value is -40.0.*
 
 **Estimated row heights:** In order to minimize CPU usage, the `TableViewScrollAndSelectController` uses the `tableView(_:estimatedHeightForRowAt:)` property of your `UITableViewDelegate` when scrolling. This helps to determine the exact speed of the scrolling and which cell to stop at when the user lifts their finger or changes direction. If you do not provide an estimated row height or if your estimated row height is not very accurate, you may find that scrolling does not always stop at the correct point. To get around this issue, you can set `shouldTrustEstimatedRowHeightWhenScrolling = false` to force the `TableViewScrollAndSelectController` to use the actual row height of each cell. This, however, may cause a slight lag in scrolling, depending on how many cells you have and how much rendering each cell is doing. The recommended approach is to set an estimated row height that is as accurate as possible.
*/
public class TableViewScrollAndSelectController {
    
    // MARK: - Properties
    public weak var delegate: TableViewScrollAndSelectDelegate?

    public var touchViewWidth: CGFloat {
        didSet {
            forceLayoutTouchView = true
            layoutTouchView()
        }
    }
    
    public var touchViewCoversSafeArea: Bool {
        didSet {
            forceLayoutTouchView = true
            layoutTouchView()
        }
    }
    
    public var topScrollingAnchor: CGFloat
    public var bottomScrollingAnchor: CGFloat
    public var scrollingSpeed: ScrollingSpeed
    
    public var enabled: Bool {
        didSet {
            if !enabled {
                invalidate()
            } else {
                layoutTouchView()
            }
        }
    }
    
    // TODO: Print some logs if in debug mode
    public var isInDebugMode: Bool {
        return debugColor != nil
    }
    
    public var shouldTrustEstimatedRowHeightWhenScrolling: Bool
    
    private var scrollAnimationDuration: Float {
        
        switch scrollingSpeed {
        case .fast:
            return 1 / 40
        case .moderate:
            return 1 / 20
        case .slow:
            return 1 / 10
        case .custom(let rowsPerSecond):
            return Float(1 / rowsPerSecond)
        }
    }
    
    // The wrapper view is a clear view placed over the left side of the tableview and contains the pan and tap gesture recognizers
    private weak var tableView: UITableView!
    private var touchView: UIView!
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var forceLayoutTouchView: Bool = true
    private var debugColor: UIColor?
    
    private var currentPanDetails = PanDetails()
    private var panTimer: Timer?
    private var panTimerStartTime: Date?
    private var panTimerStartOffset: CGPoint?
    private var panTimerDestinationOffset: CGPoint?
    private var panTimerDuration: TimeInterval?
    private var panTimerChangeCount: Int = 0
    private var panStartingIndexPath: IndexPath?
    
    // MARK: - Initialization
    public init(tableView: UITableView) {
        
        self.tableView = tableView
        
        enabled = false
        scrollingSpeed = .moderate
        touchViewWidth = 60.0
        topScrollingAnchor = 40.0
        bottomScrollingAnchor = -40.0
        shouldTrustEstimatedRowHeightWhenScrolling = true
        touchViewCoversSafeArea = true
    }
    
    public convenience init(tableView: UITableView, scrollingSpeed: ScrollingSpeed) {
        
        self.init(tableView: tableView)
        self.scrollingSpeed = scrollingSpeed
    }
    
    // MARK: - Layout
    private func layoutTouchView() {
        
        if tableView.superview == nil || (touchView != nil && !forceLayoutTouchView) {
            // If the table view is not added to the hierarchy yet, don't configure
            // Likewise, if we've already been configured, don't configure again
            return
        }
        
        forceLayoutTouchView = false
        
        touchView?.removeFromSuperview()
        touchView = UIView()
        touchView.translatesAutoresizingMaskIntoConstraints = false
        touchView.backgroundColor = debugColor ?? .clear
        touchView.alpha = 0.5
        tableView.superview!.addSubview(touchView)
        
        if touchViewCoversSafeArea {
            NSLayoutConstraint.activate([touchView.leadingAnchor.constraint(equalTo: tableView.superview!.leadingAnchor, constant: -10.0),
                                         touchView.trailingAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.leadingAnchor, constant: touchViewWidth),
                                         touchView.bottomAnchor.constraint(equalTo: tableView.superview!.bottomAnchor, constant: 10.0),
                                         touchView.topAnchor.constraint(equalTo: tableView.superview!.topAnchor)])
        } else {
            NSLayoutConstraint.activate([touchView.leadingAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.leadingAnchor, constant: -10.0),
                                         touchView.trailingAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.leadingAnchor, constant: touchViewWidth),
                                         touchView.bottomAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.bottomAnchor, constant: 10.0),
                                         touchView.topAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.topAnchor)])
        }
        tableView.superview!.bringSubview(toFront: touchView)
        tableView.superview!.layoutIfNeeded()
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.numberOfTouchesRequired = 1
        touchView.addGestureRecognizer(tapGestureRecognizer)
        
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan))
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.minimumNumberOfTouches = 1
        touchView.addGestureRecognizer(panGestureRecognizer)
    }
    
    public func setDebugMode(on: Bool, color: UIColor = .green) {
        
        debugColor = on ? color : nil
        touchView?.backgroundColor = debugColor ?? .clear
    }

    // MARK: - Memory Management
    deinit {
        invalidate()
    }
    
    public func invalidate() {
        
        if let gesture = tapGestureRecognizer, let gestures = touchView?.gestureRecognizers, gestures.contains(gesture) {
            touchView.removeGestureRecognizer(gesture)
        }
        if let gesture = panGestureRecognizer, let gestures = touchView?.gestureRecognizers, gestures.contains(gesture) {
            touchView.removeGestureRecognizer(gesture)
        }
        tapGestureRecognizer = nil
        panGestureRecognizer = nil
        
        touchView?.removeFromSuperview()
        tableView.superview?.layoutIfNeeded()
        
        panTimer?.invalidate()
        panTimer = nil
    }
    
    // MARK: - Tapping
    @objc private func tap() {
        // Allow cells to be selected / deselected by tapping as usual
        
        if let indexPath = tableView.indexPathForRow(at: tapGestureRecognizer.location(in: tableView)) {
            
            if let selectedIndexPaths = tableView.indexPathsForSelectedRows, selectedIndexPaths.contains(indexPath) {
                changeRowSelection(at: indexPath, select: false)
            } else {
                changeRowSelection(at: indexPath, select: true)
            }
        }
    }
    
    // MARK: - Panning
    @objc private func pan() {
        // When the user pans up or down above the cell selection buttons
        
        if panGestureRecognizer.state == .began {
            
            // Notify the delegate
            delegate?.tableViewSelectionPanningDidBegin()
            
            // Refresh panning details
            currentPanDetails = PanDetails()
            currentPanDetails.position = panGestureRecognizer.location(in: tableView.superview!)
            
            // Select / Deselect row
            if let indexPath = tableView.indexPathForRow(at: tableView.superview!.convert(currentPanDetails.position, to: tableView)) {
                
                panStartingIndexPath = indexPath
                
                if let selectedIndexPaths = tableView.indexPathsForSelectedRows, selectedIndexPaths.contains(indexPath) {
                    currentPanDetails.mode = .deselecting
                    changeRowSelection(at: indexPath, select: false)
                } else {
                    currentPanDetails.mode = .selecting
                    changeRowSelection(at: indexPath, select: true)
                }
            }
            
        } else if panGestureRecognizer.state == .changed {
            
            let newPanningPosition = panGestureRecognizer.location(in: tableView.superview!)
            
            if fabs(newPanningPosition.y - currentPanDetails.position.y) < 5.0 {
                // Don't worry about minute changes
                return
            }
            
            let isPanningDown = newPanningPosition.y > currentPanDetails.position.y
            let directionChanged = (isPanningDown && currentPanDetails.direction == .up) || (!isPanningDown && currentPanDetails.direction == .down)
            
            if currentPanDetails.isScrolling && !directionChanged {
                // Is we are scrolling up or down and the direction of the pan gesture did not change, don't do anything.
                // Just allow the scroll timer to continue scrolling and selecting.
                // We don't even want to save the new position, because we don't want to stop scrolling unless the pan
                // position reaches the point at which it began scrolling.
                // In other words, if the user moves their finger minutely in the opposite direction, don't stop the scroll.
                return
            }

            // Save the new position and direction of the pan
            currentPanDetails.position = newPanningPosition
            currentPanDetails.direction = isPanningDown ? .down : .up
            
            guard let indexPath = tableView.indexPathForRow(at: tableView.superview!.convert(currentPanDetails.position, to: tableView)) else {
                return
            }
            
            if directionChanged {
                
                if currentPanDetails.isScrolling {
                    // Stop scrolling
                    currentPanDetails.isScrolling = false
                    panTimer?.invalidate()
                    panTimer = nil
                }
                
                // Switch selection mode
                currentPanDetails.switchSelectionMode()
                
                // Update selection for index path that the pan gesture changed direction over
                changeRowSelection(at: indexPath, select: currentPanDetails.isSelecting)
                panStartingIndexPath = indexPath
                
//            } else if !isCellAtEdgeOfTableView(at: indexPath, direction: currentPanDetails.direction) {
            } else if !isAtEdgeOfTableView() {
                
                // Update selection for index path that the pan gesture changed direction over
                if let starting = panStartingIndexPath {
                    let rowsMissed: Int
                    if currentPanDetails.direction == .down {
                        rowsMissed = getNumberOfRowsBetween(firstIndexPath: starting, secondIndexPath: indexPath)
                    } else {
                        rowsMissed = getNumberOfRowsBetween(firstIndexPath: indexPath, secondIndexPath: starting)
                    }
                    if rowsMissed > 1 {
                        changeRowSelection(from: indexPath, numberOfRows: rowsMissed, select: currentPanDetails.isSelecting, direction: currentPanDetails.direction)
                    } else {
                        changeRowSelection(at: indexPath, select: currentPanDetails.isSelecting)
                    }
                }
                
                panStartingIndexPath = indexPath
                
            } else {

                // We need to begin scrolling
                currentPanDetails.isScrolling = true
                panStartingIndexPath = indexPath
                panTimerChangeCount = 0
                panTimerStartOffset = tableView.contentOffset
                
                let destinationIndexPath: IndexPath?
                
                if currentPanDetails.direction == .down {
                    // Scrolling down
                    panTimerDestinationOffset = CGPoint(x: tableView.contentOffset.x, y: tableView.contentSize.height - tableView.bounds.height)
                    destinationIndexPath = getLastIndexPath()
                } else {
                    // Scrolling up
                    panTimerDestinationOffset = CGPoint(x: tableView.contentOffset.x, y: -tableView.safeAreaInsets.top)
                    destinationIndexPath = getFirstIndexPath()
                }
                
                if let destination = destinationIndexPath {
                    
                    // Determine how many rows we need to scroll to get to the top/bottom
                    let rowsToScroll: Float
                    if currentPanDetails.direction == .down {
                        rowsToScroll = Float(getNumberOfRowsBetween(firstIndexPath: indexPath, secondIndexPath: destination))
                    } else {
                        rowsToScroll = Float(getNumberOfRowsBetween(firstIndexPath: destination, secondIndexPath: indexPath))
                    }
                    
                    panTimerStartTime = Date()
                    panTimerDuration = TimeInterval(rowsToScroll * scrollAnimationDuration)
                    
                    // Begin the timer
                    panTimer = Timer.scheduledTimer(timeInterval: 0.001,
                                                    target: self,
                                                    selector: #selector(scrollAndSelect),
                                                    userInfo: nil,
                                                    repeats: true)
                }
            }
            
        } else if panGestureRecognizer.state == .ended || panGestureRecognizer.state == .cancelled {
            
            // End scrolling animation
            currentPanDetails.isScrolling = false
            panTimer?.invalidate()
            panTimer = nil
            
            // Notify delegate
            delegate?.tableViewSelectionPanningDidEnd()
        }
    }
    
    @objc private func scrollAndSelect() {
        // Called by the panning timer every 0.01 seconds during a scroll and select animation
        
        if !currentPanDetails.isScrolling {
            panTimer?.invalidate()
            panTimer = nil
            return
        }
        
        let timeRunning: TimeInterval = -panTimerStartTime!.timeIntervalSinceNow
        
        let destinationOffset: CGPoint
        if shouldTrustEstimatedRowHeightWhenScrolling {
            destinationOffset = panTimerDestinationOffset!
        } else if currentPanDetails.direction == .down {
            // Scrolling down
            destinationOffset = CGPoint(x: tableView.contentOffset.x, y: tableView.contentSize.height - tableView.bounds.height)
        } else {
            // Scrolling up
            destinationOffset = CGPoint(x: tableView.contentOffset.x, y: -tableView.safeAreaInsets.top)
        }
        
        let rowsPassed = Int(timeRunning / Double(scrollAnimationDuration)) + 1
        if rowsPassed >= panTimerChangeCount {
            // We reached a new index path - time to select / deselect it
            if let selectionFromIndexPath = getRowInTableViewOffsetFrom(indexPath: panStartingIndexPath!, by: currentPanDetails.direction == .down ? panTimerChangeCount : -panTimerChangeCount) {
                changeRowSelection(from: selectionFromIndexPath, numberOfRows: rowsPassed - panTimerChangeCount, select: currentPanDetails.isSelecting, direction: currentPanDetails.direction)
                panTimerChangeCount = rowsPassed
                
            }
        }
        
        if timeRunning >= panTimerDuration! {
            
            changeRowSelection(at: currentPanDetails.direction == .down ? getLastIndexPath()! : getFirstIndexPath()!, select: currentPanDetails.isSelecting)

            // We made it to the end of the table view
            tableView.setContentOffset(destinationOffset, animated: false)
            
            // Stop timer
            panTimer?.invalidate()
            panTimer = nil
            
        } else {
            
            // Scroll the tableview
            let distanceTraveled: CGFloat
            let newOffset: CGPoint
            
            if currentPanDetails.direction == .down {
                distanceTraveled = (destinationOffset.y - panTimerStartOffset!.y) * CGFloat(timeRunning / panTimerDuration!)
                newOffset = CGPoint(x: tableView.contentOffset.x, y: panTimerStartOffset!.y + distanceTraveled)
            } else {
                distanceTraveled = fabs(panTimerStartOffset!.y - panTimerDestinationOffset!.y) * CGFloat(timeRunning / panTimerDuration!)
                newOffset = CGPoint(x: tableView.contentOffset.x, y: panTimerStartOffset!.y - distanceTraveled)
            }
            
            tableView.setContentOffset(newOffset, animated: false)
        }
        
    }
    
    // MARK: - Helper Functions
    private func getNumberOfRowsBetween(firstIndexPath first: IndexPath, secondIndexPath second: IndexPath) -> Int {
        
        var diff = 0
        var curIndexPath = first
        while curIndexPath != second {
            diff += 1
            if tableView.numberOfRows(inSection: curIndexPath.section) > curIndexPath.row + 1 {
                curIndexPath = IndexPath(row: curIndexPath.row + 1, section: curIndexPath.section)
            } else if tableView.numberOfSections > curIndexPath.section + 1 {
                curIndexPath = IndexPath(row: 0, section: curIndexPath.section + 1)
            } else {
                return -1
            }
        }
        
        return diff
    }
    
    private func getFirstIndexPath() -> IndexPath? {
        
        var section = 0
        let totalSections = tableView.numberOfSections
        
        while section < totalSections {
            
            if tableView.numberOfRows(inSection: section) > 0 {
                return IndexPath(row: 0, section: section)
            }
            section += 1
        }
        
        return nil
    }
    
    private func getLastIndexPath() -> IndexPath? {
        
        var section = tableView.numberOfSections - 1
        while section >= 0 {
            let rows = tableView.numberOfRows(inSection: section)
            if rows > 0 {
                return IndexPath(row: rows - 1, section: section)
            } else {
                section -= 1
            }
        }
        
        return nil
    }
    
    private func getRowInTableViewOffsetFrom(indexPath: IndexPath, by offset: Int) -> IndexPath? {
        
        if offset == 0 {
            return indexPath
        }
        
        var rowsCounted = 0
        var section = indexPath.section
        var row = indexPath.row
        
        let totalSections = tableView.numberOfSections
        
        while section < totalSections && section >= 0 {
            
            let rowsInSection = tableView.numberOfRows(inSection: section)
            while row < rowsInSection && row >= 0 {
                if rowsCounted == abs(offset) {
                    return IndexPath(row: row, section: section)
                }
                rowsCounted += 1
                row += offset > 0 ? 1 : -1
            }
            
            row = offset > 0 ? 0 : rowsInSection - 1
            section += offset > 0 ? 1 : -1
        }
        
        return nil
        
    }
    
    private func changeRowSelection(from fromIndexPath: IndexPath, numberOfRows: Int, select: Bool, direction: PanDirection) {
        
        var indexPath = fromIndexPath
        var count = 0
        while count < numberOfRows {
         
            changeRowSelection(at: indexPath, select: select)
            if let nextIndexPath = getRowInTableViewOffsetFrom(indexPath: indexPath, by: direction == .down ? 1 : -1) {
                indexPath = nextIndexPath
            } else {
                return
            }
            
            count += 1
        }
    }

    private func changeRowSelection(at indexPath: IndexPath, select: Bool) {
        
        if select && (tableView.indexPathsForSelectedRows == nil || !tableView.indexPathsForSelectedRows!.contains(indexPath)) {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
        } else if !select && (tableView.indexPathsForSelectedRows != nil && tableView.indexPathsForSelectedRows!.contains(indexPath)) {
            tableView.deselectRow(at: indexPath, animated: true)
            tableView.delegate?.tableView?(tableView, didDeselectRowAt: indexPath)
        }
    }
    
    private func isAtEdgeOfTableView() -> Bool {
        
        let superviewRect = UIEdgeInsetsInsetRect(tableView.superview!.frame, tableView.safeAreaInsets)
        if currentPanDetails.direction == .down {
            return currentPanDetails.position.y > (superviewRect.origin.y + superviewRect.height) + bottomScrollingAnchor
        } else {
            return currentPanDetails.position.y < superviewRect.origin.y + topScrollingAnchor
        }
    }
}

// MARK: - Delegate Protocol
/**
 The delegate of a TableViewScrollAndSelectController must adopt the TableViewScrollAndSelectDelegate protocol. The delegate is notified when the UITableView begins and ends scrolling as a result of a scroll and select action.
 
 To monitor individual row selections, do not use this protocol; instead, override the tableViewDidSelectRowAtIndexPath and tableViewDidDeselectRowAtIndexPath functions in your UITableViewController.
 */
public protocol TableViewScrollAndSelectDelegate: class {

    func tableViewSelectionPanningDidBegin()
    func tableViewSelectionPanningDidEnd()
}

// MARK: - Types
public extension TableViewScrollAndSelectController {
    
    /**
     The speed at which the UITableView will scroll when a user's panning gesture reaches the top or bottom of the view.
     * fast: 40 rows per second
     * moderate: 20 rows per second
     * slow: 10 rows per second
     * custom: x rows per second
     */
    public enum ScrollingSpeed {
        /**
         The UITableView will scroll 40 rows per second.
        */
        case fast
        /**
         The UITableView will scroll 20 rows per second.
         */
        case moderate
        /**
         The UITableView will scroll 10 rows per second.
         */
        case slow
        /**
         The UITableView will scroll a custom number of rows per second.
         */
        case custom(rowsPerSecond: Float)
    }
    
    private enum PanDirection {
        case none
        case down
        case up
    }
    
    private enum PanMode {
        case selecting
        case deselecting
    }
    
    private struct PanDetails {
        
        var direction: PanDirection = .none
        var mode: PanMode = .selecting
        var position: CGPoint = .zero
        var isScrolling: Bool = false
        
        mutating func switchSelectionMode() {
            mode = mode == .selecting ? .deselecting : .selecting
        }
        
        var isSelecting: Bool {
            return mode == .selecting
        }
    }
}
