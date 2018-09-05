//
//  UITableViewScrollAndSelectController.swift
//  TableViewScrollAndSelect
//
//  Created by Will Loderhose on 8/31/2018.
//  Copyright © 2018 Will Loderhose. All rights reserved.
//

// MARK: - ABOUT
// This class manages a pan and a tap gesture recognizer used for selecting / deselecting multiple cells in a table view and simultaneously scrolling

import UIKit

public protocol UITableViewScrollAndSelectDelegate: class {
    
    func tableViewDidAddToSelection(indexPath: IndexPath)
    func tableViewDidRemoveFromSelection(indexPath: IndexPath)
    func tableViewSelectionPanningDidBegin()
    func tableViewSelectionPanningDidEnd()
}

public class UITableViewScrollAndSelectController {
    
    // MARK: - Types
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
    
    private enum PanType {
        case selecting
        case deselecting
    }
    
    // MARK: - Properties
    public weak var delegate: UITableViewScrollAndSelectDelegate?
    
    private var needsLayout: Bool = false
    public var enabled: Bool = false {
        didSet {
            if !enabled {
//                AppDelegate.AppUtility.unlockOrientation()
                isAnimatingScroll = false
            }
            wrapperViewWidthConstraint?.constant = enabled ? touchWidth : 0
            tableView.superview?.layoutIfNeeded()
        }
    }
    
    private weak var tableView: UITableView!
    private var touchWidth: CGFloat
    private var scrollingSpeed: ScrollingSpeed
    
    // The wrapper view is a clear view placed over the left side of the tableview and contains the pan and tap gesture recognizers
    private var wrapperView: UIView!
    private var wrapperViewWidthConstraint: NSLayoutConstraint?
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    private var panTimer: Timer?
    private var panTimerStartTime: Date?
    private var panTimerStartOffset: CGPoint?
    private var panTimerDestinationOffset: CGPoint?
    private var panTimerDuration: TimeInterval?
    private var panTimerChangeCount: Int = 0
    
    private var panningPosition: CGPoint = .zero
    private var panningDirection: PanDirection = .none
    private var panningMode: PanType = .selecting
    private var startingIndexPath: IndexPath?
    
    private var isAnimatingScroll: Bool = false
    private var indexPathToScrollTo: IndexPath?
    
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
    
    deinit {
        invalidate()
    }
    
    // MARK: - Load
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
        wrapperView.backgroundColor = .clear
        wrapperViewWidthConstraint = wrapperView.widthAnchor.constraint(equalToConstant: enabled ? touchWidth : 0.0)
        tableView.superview!.addSubview(wrapperView)
        
        NSLayoutConstraint.activate([wrapperViewWidthConstraint!,
                                     wrapperView.leadingAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.leadingAnchor),
                                     wrapperView.bottomAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.bottomAnchor),
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
    
    public func updateSpeed(_ speed: ScrollingSpeed) {
        scrollingSpeed = speed
    }
    
    public func invalidate() {
        
        // Unlock app rotation
//        AppDelegate.AppUtility.unlockOrientation()
        
        delegate = nil
        
        // Release gestures
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
        
        if panGestureRecognizer.state == .began {
            
            delegate?.tableViewSelectionPanningDidBegin()
            // Don't allow the app to rotate during a pan gesture
//            AppDelegate.AppUtility.lockOrientation()
            
            // Refresh panning details
            panningDirection = .none
            isAnimatingScroll = false
            
            // Grap the initial pan position
            panningPosition = panGestureRecognizer.location(in: tableView)
            
            // Select / Deselect row
            if let indexPath = tableView.indexPathForRow(at: panningPosition) {
                if let selectedIndexPaths = tableView.indexPathsForSelectedRows, selectedIndexPaths.contains(indexPath) {
                    panningMode = .deselecting
                    changeRowSelection(at: indexPath, select: false)
                } else {
                    panningMode = .selecting
                    changeRowSelection(at: indexPath, select: true)
                }
            }
            
        } else if panGestureRecognizer.state == .changed {
            
            let newPanningPosition = panGestureRecognizer.location(in: tableView)
            let isPanningDown = newPanningPosition.y > panningPosition.y
            let directionChanged = (isPanningDown && panningDirection == .up) || (!isPanningDown && panningDirection == .down)
            let indexPathChanged = tableView.indexPathForRow(at: panningPosition) != tableView.indexPathForRow(at: newPanningPosition)
            panningPosition = newPanningPosition
            panningDirection = isPanningDown ? .down : .up
            
            if isAnimatingScroll {
                
                if directionChanged && indexPathChanged {
                    isAnimatingScroll = false
                    panningMode = panningMode == .selecting ? .deselecting : .selecting
                    
                    if let indexPath = tableView.indexPathForRow(at: panningPosition) {
                        changeRowSelection(at: indexPath, select: panningMode == .selecting)
                    }
                    
                } else {
                    // Do nothing
                }
                
            } else {
                
                if directionChanged {
                    
                    panningMode = panningMode == .selecting ? .deselecting : .selecting
                    
                    if let indexPath = tableView.indexPathForRow(at: panningPosition) {
                        changeRowSelection(at: indexPath, select: panningMode == .selecting)
                    }
                    
                } else {

                    if let indexPath = tableView.indexPathForRow(at: panningPosition) {
                        
                        if isCellFullyVisible(at: indexPath) {
                            changeRowSelection(at: indexPath, select: panningMode == .selecting)
                        } else {
                            // It's time to start the scrolling animation
                            isAnimatingScroll = true
                            startingIndexPath = tableView.indexPathForRow(at: panningPosition)
//                            scrollToLastRow()
                            let rowsToScroll = Float(getNumberOfRowsBetween(firstIndexPath: tableView.indexPathForRow(at: panningPosition)!, secondIndexPath: getLastIndexPath()!))
                            panTimerChangeCount = 0
                            panTimerDuration = TimeInterval(rowsToScroll * scrollAnimationDuration)
                            panTimerStartTime = Date()
                            panTimerStartOffset = tableView.contentOffset
                            panTimerDestinationOffset = CGPoint(x: tableView.contentOffset.x, y: tableView.contentSize.height - UIEdgeInsetsInsetRect(tableView.bounds, tableView.safeAreaInsets).height)
                            panTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(actuallyScrollToLastRow), userInfo: nil, repeats: true)
//                            indexPathToScrollTo = indexPath
//                            scrollToNextRow()
                        }
                    } else {
                        print("uh oh")
                    }
                    
                }
            }
            
            
        } else if panGestureRecognizer.state == .ended || panGestureRecognizer.state == .cancelled {
            
            isAnimatingScroll = false
            delegate?.tableViewSelectionPanningDidEnd()
//            AppDelegate.AppUtility.unlockOrientation()
        }
    }
    
    @objc private func actuallyScrollToLastRow() {
        
        if !isAnimatingScroll {
            panTimer?.invalidate()
            panTimer = nil
            return
        }
        
        let timeRunning: TimeInterval = -panTimerStartTime!.timeIntervalSinceNow
        
        if timeRunning >= panTimerDuration! {
            tableView.setContentOffset(panTimerDestinationOffset!, animated: false)
            panTimer?.invalidate()
            panTimer = nil
            changeRowSelection(at: getLastIndexPath()!, select: panningMode == .selecting)
        } else {
            if Int(timeRunning / Double(scrollAnimationDuration)) > panTimerChangeCount {
                if let nextIndexPath = getRowInTableViewOffsetFrom(indexPath: startingIndexPath!, by: panTimerChangeCount) {
//                    print("\(Int(timeRunning / Double(scrollAnimationDuration))) - \(panTimerChangeCount)")
                    print(nextIndexPath)
                    changeRowSelection(at: nextIndexPath, select: panningMode == .selecting)
                    panTimerChangeCount += 1
                }
            }
            let newOffset = CGPoint(x: tableView.contentOffset.x, y: panTimerStartOffset!.y + ((panTimerDestinationOffset!.y - panTimerStartOffset!.y) * CGFloat(timeRunning / panTimerDuration!)))
            tableView.setContentOffset(newOffset, animated: false)
        }
        
    }
    
    private func scrollToLastRow() {
        
        if let lastIndexPath = getLastIndexPath(), let firstIndexPath = startingIndexPath {
            
            let rowsToScroll = Float(getNumberOfRowsBetween(firstIndexPath: firstIndexPath, secondIndexPath: lastIndexPath))
            if rowsToScroll > 0 {
                
                print("about to scroll to bottom - \(Date())")
                
                panTimer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(actuallyScrollToLastRow), userInfo: nil, repeats: true)
//                UIView.animate(withDuration: TimeInterval(scrollAnimationDuration * rowsToScroll),
//                               delay: 0.0,
//                               options: [.curveEaseOut, .allowUserInteraction],
//                               animations: { [unowned self] in
//
////                                self.tableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: false)
////                                self.tableView.contentOffset = CGPoint(x: 0.0, y: self.tableView.contentSize.height - self.tableView.bounds.height - self.tableView.superview!.safeAreaInsets.top)
//                                self.tableView.scrollRectToVisible(CGRect(x: 0.0, y: self.tableView.contentSize.height - self.tableView.bounds.height - self.tableView.superview!.safeAreaInsets.top, width: self.tableView.bounds.width, height: self.tableView.bounds.height), animated: false)
//
//                    }, completion: { (finished)  in
//
//                        print("finished scrolling to bottom - \(Date())")
//                    })
                
            }
            
        }
    }
    
    private func scrollToNextRow() {

        print("starting - \(Date().description)")
        if !isAnimatingScroll || indexPathToScrollTo == nil {
            return
        }
        
        UIView.animate(withDuration: TimeInterval(scrollAnimationDuration),
                       delay: 0.0,
                       options: [.curveLinear, .allowUserInteraction],
                       animations: { [unowned self] in
                        
                        self.tableView.scrollToRow(at: self.indexPathToScrollTo!, at: self.panningDirection == .down ? .bottom : .top, animated: false)
                        
            }, completion: { (finished)  in
                
                self.changeRowSelection(at: self.indexPathToScrollTo!, select: self.panningMode == .selecting)
                
                if let nextIndexPath = self.getNextRowInTableView(indexPath: self.indexPathToScrollTo!), self.isAnimatingScroll {
                    self.indexPathToScrollTo = nextIndexPath
                    self.scrollToNextRow()
                }
                
                print("ending - \(Date().description)")
                
            })
        
    }
    
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
        
    private func getNextRowInTableView(indexPath: IndexPath) -> IndexPath? {
        
        let rowsInSection = tableView.numberOfRows(inSection: indexPath.section)
        if indexPath.row < rowsInSection {
            return IndexPath(row: indexPath.row + 1, section: indexPath.section)
        }
        
        var section = indexPath.section + 1
        while section < tableView.numberOfSections {
            if tableView.numberOfRows(inSection: section) > 0 {
                return IndexPath(row: 0, section: section)
            } else {
                section += 1
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
        
        while section < totalSections {
            
            let rowsInSection = tableView.numberOfRows(inSection: section)
            while row < rowsInSection {
                if rowsCounted == offset {
                    return IndexPath(row: row, section: section)
                }
                rowsCounted += 1
                row += 1
            }
            
            row = 0
            section += 1
        }
        
        return nil
        
    }
    
//    private func updateSelectionAndAutoScrollIfNecessary(at indexPath: IndexPath, isScrolling: Bool = false) {
//
//        DispatchQueue.main.async { [unowned self] in
//
//            if self.autoScroll {
//
//                let sections = self.tableView.numberOfSections
//                if sections == 0 {
//                    return
//                }
//
//                let rowsInLastSection = self.tableView.numberOfRows(inSection: sections - 1)
//                if rowsInLastSection == 0 {
//                    return
//                }
//
//                let shouldSelect = self.panningMode == .selecting
//
//                if indexPath.row == rowsInLastSection - 1 && self.panningDirection == .down {
//                    // This is the last row in the table view
//                    self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
//                    self.changeRowSelection(at: indexPath, select: shouldSelect)
//                    self.autoScroll = false
//
//                } else if indexPath.row == 0 && self.panningDirection == .up {
//                    // This is the first row in the table view
//                    self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
//                    self.changeRowSelection(at: indexPath, select: shouldSelect)
//                    self.autoScroll = false
//
//                } else {
//
//                    let nextIndexPath: IndexPath
//                    if self.tableView.numberOfRows(inSection: indexPath.section) - 1 == indexPath.row {
//                        if indexPath.section == sections - 1 {
//                            return
//                        }
//                        nextIndexPath = IndexPath(row: 0, section: indexPath.section + 1)
//                    } else {
//                        nextIndexPath = IndexPath(row: indexPath.row + (self.panningDirection == .down ? 1 : -1), section: indexPath.section)
//                    }
//
//                    let scrollPosition: UITableViewScrollPosition = self.panningDirection == .down ? .bottom : .top
//
//                    if !self.isCellFullyVisible(at: indexPath) {
//                        // The cell is not yet fully visible - scroll to it
//                        if !isScrolling {
//                            print("1")
//                            self.scrollToRow(at: indexPath, at: scrollPosition, completion: { (finished) in
//                                if self.autoScroll {
//                                    self.updateSelectionAndAutoScrollIfNecessary(at: indexPath, isScrolling: true)
//                                }
//                            })
//                        }
////                        DispatchQueue(label: "TableViewScrollAndSelect").async {
////                            self.updateSelectionAndAutoScrollIfNecessary(at: indexPath, isScrolling: true)
////                        }
//
//                    } else if !self.isCellFullyVisible(at: nextIndexPath) {
//                        // The cell is fully visible, but the next one isn't
//                        self.changeRowSelection(at: indexPath, select: shouldSelect)
//                        print("2")
//                        self.scrollToRow(at: nextIndexPath, at: scrollPosition, completion: { (finished) in
//                            if self.autoScroll {
//                                self.updateSelectionAndAutoScrollIfNecessary(at: nextIndexPath, isScrolling: true)
//                            }
//                        })
////                        DispatchQueue(label: "TableViewScrollAndSelect").async {
////                            self.updateSelectionAndAutoScrollIfNecessary(at: nextIndexPath, isScrolling: true)
////                        }
//
//                    } else {
//                        // We are currently panning across a row that is not at the top or bottom of the table view
//                        // We simply want to update the selection without auto scrolling
//                        self.changeRowSelection(at: indexPath, select: shouldSelect)
//                    }
//                }
//            } else {
//                print("We cancelled a background auto scroll operation!")
//            }
//        }
//    }
//
//    private func scrollToRow(at indexPath: IndexPath, at position: UITableViewScrollPosition, completion: @escaping (Bool) -> ()) {
//
//        if self.autoScroll {
//
//            let duration: TimeInterval
//
//            switch self.scrollingSpeed {
//            case .fast:
//                duration = 0.15
//            case .moderate:
//                duration = 0.25
//            case .slow:
//                duration = 0.25
//            case .custom:
//                duration = 0.25
//            }
//
//            UIView.animate(withDuration: 3,
//                           delay: 0.0,
//                           options: [.curveLinear],
//                           animations: { [unowned self] in
//                            if self.autoScroll {
//                                self.tableView.scrollToRow(at: indexPath, at: position, animated: false)
//                            }
//
//                       }, completion: completion)
//        }
//    }
    
    // MARK: - Private Functions
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
        return tableView.bounds.contains(adjustedRect)
    }
}
