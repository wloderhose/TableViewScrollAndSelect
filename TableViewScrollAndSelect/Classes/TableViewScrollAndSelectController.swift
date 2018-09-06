//
//  TableViewScrollAndSelectController.swift
//  TableViewScrollAndSelect
//
//  Created by Will Loderhose on 8/31/2018.
//  Copyright © 2018 Will Loderhose. All rights reserved.
//

// MARK: - ABOUT
// This class manages a pan and a tap gesture recognizer used for selecting / deselecting multiple cells in a table view and simultaneously scrolling

import UIKit

public class TableViewScrollAndSelectController {
    
    // MARK: - Properties
    public weak var delegate: TableViewScrollAndSelectDelegate?
    
    public var touchWidth: CGFloat
    public var scrollingSpeed: ScrollingSpeed
    
    public var enabled: Bool = false {
        didSet {
            if !enabled {
                panTimer?.invalidate()
                panTimer = nil
                currentPanDetails = PanDetails()
            }
            wrapperViewWidthConstraint?.constant = enabled ? touchWidth : 0
            tableView.superview?.layoutIfNeeded()
        }
    }
    
    public var isInDebugMode: Bool {
        return debugColor != nil
    }
    
    private var scrollAnimationDuration: Float {
        
        switch scrollingSpeed {
        case .fast:
            return 0.025
        case .moderate:
            return 0.05
        case .slow:
            return 0.1
        case .custom(let rowsPerSecond):
            return Float(1 / rowsPerSecond)
        }
    }
    
    // The wrapper view is a clear view placed over the left side of the tableview and contains the pan and tap gesture recognizers
    private weak var tableView: UITableView!
    private var wrapperView: UIView!
    private var wrapperViewWidthConstraint: NSLayoutConstraint?
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var needsLayout: Bool = false
    private var debugColor: UIColor?
    
    private var currentPanDetails = PanDetails()
    private var panTimer: Timer?
    private var panTimerStartTime: Date?
    private var panTimerStartOffset: CGPoint?
    private var panTimerDestinationOffset: CGPoint?
    private var panTimerDuration: TimeInterval?
    private var panTimerChangeCount: Int = 0
    private var panTimerStartingIndexPath: IndexPath?
    
    // MARK: - Init
    public init(tableView: UITableView) {
        
        self.tableView = tableView
        self.touchWidth = 60.0
        self.scrollingSpeed = .moderate
    }
    
    public convenience init(tableView: UITableView, touchWidth: CGFloat) {
        
        self.init(tableView: tableView)
        self.touchWidth = touchWidth
    }
    
    public convenience init(tableView: UITableView, scrollingSpeed: ScrollingSpeed) {
        
        self.init(tableView: tableView)
        self.scrollingSpeed = scrollingSpeed
    }
    
    public convenience init(tableView: UITableView, touchWidth: CGFloat, scrollingSpeed: ScrollingSpeed) {
        
        self.init(tableView: tableView)
        self.touchWidth = touchWidth
        self.scrollingSpeed = scrollingSpeed
    }
    
    // MARK: - Layout
    public func setNeedsLayout() {
        needsLayout = true
    }
    
    public func layoutIfNeeded() {
        
        if (tableView.superview == nil || wrapperView != nil) && !needsLayout {
            // If the table view is not added to the hierarchy yet, don't configure
            // Likewise, if we've already been configured, don't configure again
            return
        }
        
        needsLayout = false
        
        wrapperView = UIView()
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        wrapperView?.backgroundColor = debugColor ?? .clear
        wrapperView?.alpha = 0.5
        wrapperViewWidthConstraint = wrapperView.widthAnchor.constraint(equalToConstant: enabled ? touchWidth : 0.0)
        tableView.superview!.addSubview(wrapperView)
        
        NSLayoutConstraint.activate([wrapperViewWidthConstraint!,
                                     wrapperView.leadingAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.leadingAnchor, constant: -10.0),
                                     wrapperView.bottomAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.bottomAnchor, constant: 10.0),
                                     wrapperView.topAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.topAnchor)])
        tableView.superview!.bringSubview(toFront: wrapperView)
        tableView.superview!.layoutIfNeeded()
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.numberOfTouchesRequired = 1
        wrapperView.addGestureRecognizer(tapGestureRecognizer)
        
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan))
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.minimumNumberOfTouches = 1
        wrapperView.addGestureRecognizer(panGestureRecognizer)
    }
    
    public func setDebugMode(on: Bool, color: UIColor = .green) {
        
        debugColor = on ? color : nil
        wrapperView?.backgroundColor = debugColor ?? .clear
    }

    // MARK: - Memory Management
    deinit {
        invalidate()
    }
    
    public func invalidate() {
        
        if let gesture = tapGestureRecognizer, let gestures = wrapperView.gestureRecognizers, gestures.contains(gesture) {
            wrapperView.removeGestureRecognizer(gesture)
        }
        if let gesture = panGestureRecognizer, let gestures = wrapperView.gestureRecognizers, gestures.contains(gesture) {
            wrapperView.removeGestureRecognizer(gesture)
        }
        tapGestureRecognizer = nil
        panGestureRecognizer = nil
        
        wrapperView.removeFromSuperview()
        
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
            currentPanDetails.position = panGestureRecognizer.location(in: tableView)
            
            // Select / Deselect row
            if let indexPath = tableView.indexPathForRow(at: currentPanDetails.position) {
                if let selectedIndexPaths = tableView.indexPathsForSelectedRows, selectedIndexPaths.contains(indexPath) {
                    currentPanDetails.mode = .deselecting
                    changeRowSelection(at: indexPath, select: false)
                } else {
                    currentPanDetails.mode = .selecting
                    changeRowSelection(at: indexPath, select: true)
                }
            }
            
        } else if panGestureRecognizer.state == .changed {
            
            let newPanningPosition = panGestureRecognizer.location(in: tableView)
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
            
            guard let indexPath = tableView.indexPathForRow(at: currentPanDetails.position) else {
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
                
            } else if isCellFullyVisible(at: indexPath) {
                
                // Update selection for index path that the pan gesture changed direction over
                changeRowSelection(at: indexPath, select: currentPanDetails.isSelecting)
                
            } else {

                print("Cell is not fully visible")

                // We need to begin scrolling
                currentPanDetails.isScrolling = true
                panTimerStartingIndexPath = indexPath
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
        
        if timeRunning >= panTimerDuration! {
            
            // We made it to the end of the table view
            tableView.setContentOffset(panTimerDestinationOffset!, animated: false)
            
            // Select / deselect final index path
            if let indexPath = currentPanDetails.direction == .down ? getLastIndexPath() : getFirstIndexPath() {
                changeRowSelection(at: indexPath, select: currentPanDetails.isSelecting)
            }
            
            // Stop timer
            panTimer?.invalidate()
            panTimer = nil
            
        } else {
            
            print("time - \(Int(timeRunning / Double(scrollAnimationDuration)))")
            print("count - \(panTimerChangeCount)")
            let rowsPassed = Int(timeRunning / Double(scrollAnimationDuration))
            if rowsPassed > panTimerChangeCount {
                // We reached a new index path - time to select / deselect it
                if let selectionFromIndexPath = getRowInTableViewOffsetFrom(indexPath: panTimerStartingIndexPath!, by: currentPanDetails.direction == .down ? panTimerChangeCount : -panTimerChangeCount) {
                    changeRowSelection(from: selectionFromIndexPath, numberOfRows: rowsPassed - panTimerChangeCount, select: currentPanDetails.isSelecting, direction: currentPanDetails.direction)
                    panTimerChangeCount = rowsPassed
                    
                }
//                if let nextIndexPath = getRowInTableViewOffsetFrom(indexPath: panTimerStartingIndexPath!, by: currentPanDetails.direction == .down ? panTimerChangeCount : -panTimerChangeCount) {
//                    changeRowSelection(at: nextIndexPath, select: currentPanDetails.isSelecting)
//                    print("nextIndexPath - \(nextIndexPath)")
//                }
            }
            
            // Scroll the tableview
            let distanceTraveled: CGFloat
            let newOffset: CGPoint
            
            if currentPanDetails.direction == .down {
                distanceTraveled = (panTimerDestinationOffset!.y - panTimerStartOffset!.y) * CGFloat(timeRunning / panTimerDuration!)
                newOffset = CGPoint(x: tableView.contentOffset.x, y: panTimerStartOffset!.y + distanceTraveled)
            } else {
                distanceTraveled = fabs(panTimerStartOffset!.y - panTimerDestinationOffset!.y) * CGFloat(timeRunning / panTimerDuration!)
                newOffset = CGPoint(x: tableView.contentOffset.x, y: panTimerStartOffset!.y - distanceTraveled)
            }
            
//            print("distanceToTravel = \(distanceTraveled); newOffset = \(newOffset)")
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
        
        print("selecting - \(fromIndexPath), num - \(numberOfRows)")
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
        
        if select {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
            delegate?.tableViewDidAddToSelection(indexPath: indexPath)
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
            tableView.delegate?.tableView?(tableView, didDeselectRowAt: indexPath)
            delegate?.tableViewDidRemoveFromSelection(indexPath: indexPath)
        }
    }
    
    private func isCellFullyVisible(at indexPath: IndexPath) -> Bool {
        
        // Determine if a cell is fully visible in the table view currently
        let cellRect = tableView.rectForRow(at: indexPath)
        
        // Necessary hack to make it work when the cell is exactly positioned at the bottom of the table view
        // The scroll view rightfully doesn't think it needs to be scrolled, so the scrollViewDidEnd event never gets fired
        // We need to subtract 1 pixel from this test to make everything work properly
        let adjustedRect = CGRect(origin: cellRect.origin, size: CGSize(width: cellRect.width, height: cellRect.height + 1.0))
        return UIEdgeInsetsInsetRect(tableView.bounds, tableView.safeAreaInsets).contains(adjustedRect)
    }
}

// MARK: - Delegate Protocol
public protocol TableViewScrollAndSelectDelegate: class {
    
    func tableViewDidAddToSelection(indexPath: IndexPath)
    func tableViewDidRemoveFromSelection(indexPath: IndexPath)
    func tableViewSelectionPanningDidBegin()
    func tableViewSelectionPanningDidEnd()
}

// MARK: - Types
public extension TableViewScrollAndSelectController {
    
    public enum ScrollingSpeed {
        case fast
        case moderate
        case slow
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
