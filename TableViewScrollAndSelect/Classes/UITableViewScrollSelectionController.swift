//
//  UITableViewScrollSelectionController
//  TableViewScrollAndSelect
//
//  Created by Will Loderhose on 8/31/2018.
//  Copyright © 2018 Will Loderhose. All rights reserved.
//

// MARK: - ABOUT
// This class manages a pan and a tap gesture recognizer used for selecting / deselecting multiple cells in a table view and simultaneously scrolling

import UIKit

public protocol UITableViewScrollSelectionDelegate: class {
    
    func tableViewScrollSelectionDidBegin()
    func tableViewScrollSelectionDidSelectAt(_ indexPath: IndexPath)
    func tableViewScrollSelectionDidDeselectAt(_ indexPath: IndexPath)
    func tableViewScrollSelectionDidEnd()
}

public class UITableViewScrollSelectionController {
    
    // MARK: - Types
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
    weak var tableView: UITableView!
    weak var delegate: UITableViewScrollSelectionDelegate?
    var touchWidth: CGFloat = 60.0
    
    private var superview: UIView? {
        return tableView.superview
    }
    
    private var enabled: Bool = false {
        didSet {
            if !enabled {
//                AppDelegate.AppUtility.unlockOrientation()
                autoScroll = false
            }
            wrapperViewWidthConstraint.constant = enabled ? touchWidth : 0
            superview?.layoutIfNeeded()
        }
    }
    
    // The wrapper view is a clear view placed over the left side of the tableview and contains the pan and tap gesture recognizers
    private var wrapperView: UIView!
    private var wrapperViewWidthConstraint: NSLayoutConstraint!
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    private var panningPosition: CGPoint = .zero
    private var panningDirection: PanDirection = .none
    private var panningType: PanType = .selecting
    private var autoScroll: Bool = false
    
    private var tableViewSuperviewObserver: NSKeyValueObservation?
    private var tableViewEditingObserver: NSKeyValueObservation?
    
    // MARK: - Load
    init(tableView: UITableView) {
        
        self.tableView = tableView
        
        tableViewSuperviewObserver = tableView.observe(\UITableView.superview, options: [.new]) { [unowned self] (tableView, change) in
            if self.superview != nil {
                self.configure()
            }
        }
        
        tableViewSuperviewObserver = tableView.observe(\UITableView.isEditing, options: [.new]) { [unowned self] (tableView, change) in
            self.enabled = change.newValue ?? false
        }
    }
    
    convenience init(tableView: UITableView, touchWidth: CGFloat) {
        
        self.init(tableView: tableView)
        self.touchWidth = touchWidth
    }
    
    private func configure() {
        
        wrapperView = UIView()
        wrapperView.translatesAutoresizingMaskIntoConstraints = false
        wrapperView.backgroundColor = .clear
        wrapperViewWidthConstraint = NSLayoutConstraint(item: wrapperView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: tableView.isEditing ? 60 : 0)
        superview!.addSubview(wrapperView)
        
        NSLayoutConstraint.activate([wrapperViewWidthConstraint,
                                     wrapperView.leadingAnchor.constraint(equalTo: superview!.layoutMarginsGuide.leadingAnchor),
                                     wrapperView.bottomAnchor.constraint(equalTo: superview!.layoutMarginsGuide.bottomAnchor),
                                     wrapperView.topAnchor.constraint(equalTo: superview!.layoutMarginsGuide.topAnchor)])
        superview!.bringSubview(toFront: wrapperView)
        superview!.layoutIfNeeded()
        
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.numberOfTouchesRequired = 1
        wrapperView.addGestureRecognizer(tapGestureRecognizer)
        
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan))
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.minimumNumberOfTouches = 1
        wrapperView.addGestureRecognizer(panGestureRecognizer)
    }
    
    func invalidate() {
        
        // Unlock app rotation
//        AppDelegate.AppUtility.unlockOrientation()
        
        delegate = nil
        
        tableViewSuperviewObserver?.invalidate()
        tableViewSuperviewObserver = nil
        
        tableViewEditingObserver?.invalidate()
        tableViewEditingObserver = nil
        
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
            
            delegate?.tableViewScrollSelectionDidBegin()
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
            delegate?.tableViewScrollSelectionDidEnd()
//            AppDelegate.AppUtility.unlockOrientation()
//            AudioManager.shared.stopSounds(.tock)
        }
    }
    
    private func updateSelectionAndAutoScrollIfNecessary(at indexPath: IndexPath, isScrolling: Bool = false) {
        
        DispatchQueue.main.async { [unowned self] in
            
            if self.autoScroll {
                
                let shouldSelect = self.panningType == .selecting
                
                if indexPath.row == self.tableView.numberOfRows(inSection: 0) - 1 && self.panningDirection == .down {
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
                    
                    let scrollPosition: UITableViewScrollPosition = self.panningDirection == .down ? .bottom : .top
                    let nextIndexPath = IndexPath(row: indexPath.row + (self.panningDirection == .down ? 1 : -1), section: 0)
                    
                    if !self.isCellFullyVisible(at: indexPath) {
                        // The cell is not yet fully visible - scroll to it
                        if !isScrolling {
                            self.scrollToRow(at: indexPath, at: scrollPosition)
                        }
                        DispatchQueue(label: "background").async {
                            self.updateSelectionAndAutoScrollIfNecessary(at: indexPath, isScrolling: true)
                        }
                        
                    } else if !self.isCellFullyVisible(at: nextIndexPath) {
                        // The cell is fully visible, so update the selection and go to the next one
                        self.changeRowSelection(at: indexPath, select: shouldSelect)
                        self.scrollToRow(at: nextIndexPath, at: scrollPosition)
                        DispatchQueue(label: "background").async {
                            self.updateSelectionAndAutoScrollIfNecessary(at: nextIndexPath, isScrolling: true)
                        }
                        
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
        
        UIView.animate(withDuration: 0.15, delay: 0.0, options: [.curveLinear], animations: { [unowned self] in
            self.tableView.scrollToRow(at: indexPath, at: position, animated: false)
            }, completion: nil)
    }
    
    @objc private func scroll() {
        
        tableView.scrollRectToVisible(CGRect(x: 0, y: tableView.contentOffset.y + 1, width: tableView.frame.width, height: tableView.frame.height), animated: true)
    }
    
    // MARK: - Private Functions
    private func changeRowSelection(at indexPath: IndexPath, select: Bool) {
        
        if select {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
            delegate?.tableViewScrollSelectionDidSelectAt(indexPath)
        } else {
            tableView.deselectRow(at: indexPath, animated: true)
            tableView.delegate?.tableView?(tableView, didDeselectRowAt: indexPath)
            delegate?.tableViewScrollSelectionDidDeselectAt(indexPath)
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
