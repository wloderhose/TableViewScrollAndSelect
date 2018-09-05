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
    public weak var tableView: UITableView!
    public var touchWidth: CGFloat
    public var scrollingSpeed: ScrollingSpeed
    
    public weak var delegate: UITableViewScrollAndSelectDelegate?
    
    public var enabled: Bool = false {
        didSet {
            if !enabled {
//                AppDelegate.AppUtility.unlockOrientation()
                autoScroll = false
            }
            wrapperViewWidthConstraint?.constant = enabled ? touchWidth : 0
            tableView.superview?.layoutIfNeeded()
        }
    }
    
    // The wrapper view is a clear view placed over the left side of the tableview and contains the pan and tap gesture recognizers
    private var wrapperView: UIView!
    private var wrapperViewWidthConstraint: NSLayoutConstraint?
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    private var panTimer: Timer?
    
    private var panningPosition: CGPoint = .zero
    private var panningDirection: PanDirection = .none
    private var panningType: PanType = .selecting
    private var autoScroll: Bool = false
    
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
    
    public func configure() {
        
        if tableView.superview == nil || wrapperView != nil {
            // If the table view is not added to the hierarchy yet, don't configure
            // Likewise, if we've already been configured, don't configure again
            return
        }
        
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
        
        // Remove wrapper view
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
            panningType = .selecting
            panningDirection = .none
            autoScroll = false
            
            // Grap the initial pan position
            panningPosition = panGestureRecognizer.location(in: tableView)
            
            // Select / Deselect row
            if let indexPath = tableView.indexPathForRow(at: panningPosition) {
                if let selectedIndexPaths = tableView.indexPathsForSelectedRows, selectedIndexPaths.contains(indexPath) {
                    panningType = .deselecting
                    changeRowSelection(at: indexPath, select: false)
                } else {
                    changeRowSelection(at: indexPath, select: true)
                }
            }
            
        } else if panGestureRecognizer.state == .changed {
            
            autoScroll = true
            let newPanningPosition = panGestureRecognizer.location(in: tableView)
            let isPanningDown = newPanningPosition.y > panningPosition.y
            
            // If direction was just reversed, then change from selecting to deselecting or vice versa
            var directionChanged = false
            if (isPanningDown && panningDirection == .up) || (!isPanningDown && panningDirection == .down) {
                panningType = (panningType == .selecting) ? .deselecting : .selecting
                directionChanged = true
                autoScroll = false
            }
            
            // Save the new panning direction
            panningDirection = isPanningDown ? .down : .up
            
            if let initialIndexPath = tableView.indexPathForRow(at: panningPosition), let newIndexPath = tableView.indexPathForRow(at: newPanningPosition) {
                
                if initialIndexPath != newIndexPath || directionChanged {
                    
                    panningPosition = newPanningPosition
                    autoScroll = true
                    updateSelectionAndAutoScrollIfNecessary(at: newIndexPath)
                }
            }
        } else if panGestureRecognizer.state == .ended || panGestureRecognizer.state == .cancelled {
            
            autoScroll = false
            tableView.layer.removeAllAnimations()
            delegate?.tableViewSelectionPanningDidEnd()
//            AppDelegate.AppUtility.unlockOrientation()
//            AudioManager.shared.stopSounds(.tock)
        }
    }
    
    private func updateSelectionAndAutoScrollIfNecessary(at indexPath: IndexPath, isScrolling: Bool = false) {
        
        DispatchQueue.main.async { [unowned self] in
            
            if self.autoScroll {
                
                let sections = self.tableView.numberOfSections
                if sections == 0 {
                    return
                }
                
                let rowsInLastSection = self.tableView.numberOfRows(inSection: sections - 1)
                if rowsInLastSection == 0 {
                    return
                }
                
                let shouldSelect = self.panningType == .selecting
                
                if indexPath.row == rowsInLastSection - 1 && self.panningDirection == .down {
                    // This is the last row in the table view
                    self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
                    self.changeRowSelection(at: indexPath, select: shouldSelect)
                    self.autoScroll = false
                    
                } else if indexPath.row == 0 && self.panningDirection == .up {
                    // This is the first row in the table view
                    self.tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                    self.changeRowSelection(at: indexPath, select: shouldSelect)
                    self.autoScroll = false
                    
                } else {
                    
                    let nextIndexPath: IndexPath
                    if self.tableView.numberOfRows(inSection: indexPath.section) - 1 == indexPath.row {
                        if indexPath.section == sections - 1 {
                            return
                        }
                        nextIndexPath = IndexPath(row: 0, section: indexPath.section + 1)
                    } else {
                        nextIndexPath = IndexPath(row: indexPath.row + (self.panningDirection == .down ? 1 : -1), section: indexPath.section)
                    }
                    
                    let scrollPosition: UITableViewScrollPosition = self.panningDirection == .down ? .bottom : .top
                    
                    if !self.isCellFullyVisible(at: indexPath) {
                        // The cell is not yet fully visible - scroll to it
                        if !isScrolling {
                            self.scrollToRow(at: indexPath, at: scrollPosition)
                        }
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5.0, execute: {
                            self.updateSelectionAndAutoScrollIfNecessary(at: indexPath, isScrolling: true)
                        })
                        
                    } else if !self.isCellFullyVisible(at: nextIndexPath) {
                        // The cell is fully visible, so update the selection and go to the next one
                        self.changeRowSelection(at: indexPath, select: shouldSelect)
                        self.scrollToRow(at: nextIndexPath, at: scrollPosition)
                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5.0, execute: {
                            self.updateSelectionAndAutoScrollIfNecessary(at: nextIndexPath, isScrolling: true)
                        })
                        
                    } else {
                        // We are currently panning across a row that is not at the top or bottom of the table view
                        // We simply want to update the selection without auto scrolling
                        self.changeRowSelection(at: indexPath, select: shouldSelect)
                    }
                }
            } else {
                print("We cancelled a background auto scroll operation!")
            }
        }
    }
    
    private func scrollToRow(at indexPath: IndexPath, at position: UITableViewScrollPosition) {
        
        let duration: TimeInterval
        
        switch scrollingSpeed {
        case .fast:
            duration = 0.15
        case .moderate:
            duration = 0.25
        case .slow:
            duration = 0.5
        }
        
        UIView.animate(withDuration: 2,
                       delay: 0.0,
                       options: [.curveLinear, .allowUserInteraction],
                       animations: { [unowned self] in
                        self.tableView.scrollToRow(at: indexPath, at: position, animated: false)
                       }, completion: nil)
    }
    
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
        let adjustedRect = CGRect(origin: cellRect.origin, size: CGSize(width: cellRect.width, height: cellRect.height - 1.0))
        return tableView.bounds.contains(adjustedRect)
    }
}
