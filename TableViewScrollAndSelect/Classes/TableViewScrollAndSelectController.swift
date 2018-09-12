//
//  TableViewScrollAndSelectController.swift
//  TableViewScrollAndSelect
//
//  Created by Will Loderhose on 8/31/2018.
//  Copyright © 2018 Will Loderhose. All rights reserved.
//

import UIKit

/**
 Allows a `UITableView` to simultaneously scroll and select cells in response to simple pan gestures.
 
 # Important
 * **This class does not replace UITableViewController or create a UITableView.** In order to instantiate a `TableViewScrollAndSelectController`, you must provide it with a `UITableView` to which it will hold a weak reference.
 
 * `TableViewScrollAndSelectController` is **disabled by default.** To enable, set `enabled = true` and be sure that your `UITableView` is part of the app's view hierarchy when you do so.
 
 * Your `UITableView` must allow multiple selection during editing and enable scrolling.
 
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
 
    // It is recommended that you enable when the table view begins editing
    // and disable when the table view ends editing
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
 **Table view requirements:** There are only 2 requirements for your `UITableView`:
 1. It must allow multiple selection during editing. You can do this in Interface Builder or set `tableView.allowsMultipleSelectionWhileEditing = true`.
 2. It must allow scrolling. You can do this in Interface Builder or set `tableView.isScrollEnabled = true`.
 
 `TableViewScrollAndSelect` supports any number of rows and sections as well as both `plain` and `grouped` styles.
 
 **Touch view:** `TableViewScrollAndSelectController` adds an invisible `UIView` as the topmost view over your `UITableView`. This touch view and your `UITableView` share the same superview. The touch view receives pan and tap gestures from the user, interprets them, and updates the selection and scrolling of your `UITableView` accordingly.
 * The touch view uses auto layout.
 * The touch view is automatically added or removed from the superview when you change the `enabled` property of the `TableViewScrollAndSelectController`. It is also removed when you call `invalidate()`.
 * By default, the touch view is 60 pixels wide. You can change this by setting the `touchAreaWidth` property to a custom value.
 * By default, the touch view extends to the top, left, and bottom edges of the superview (not safe area). If you would like it to extend only to the safe area, set `touchViewCoversSafeArea = false`.
 * Upon deinitialization, `TableViewScrollAndSelectController` will automatically remove its touch view from the view hierarchy. However, you can also do this manually by calling the `invalidate()` method , or setting `enabled = false`.
 
 **Tapping:** Tapping on the touch view simply selects / deselects that cell as it normally would.
 
 **Panning:** Panning vertically will select or deselect multiple cells. During a pan gesture, the first cell encountered determines if we are selecting or deslecting cells. For example, if the first cell in the pan was currently deselected, the `TableViewScrollAndSelectController` will select this and all other cells reached during this pan gesture.
 
 **Changing pan direction:** If the pan changes direction, the `TableViewScrollAndSelectController` will switch from selecting to deselecting, or vice versa.
 
 **Automatic scrolling:** If a pan reaches the top or bottom edge of the `UITableView`, the `TableViewScrollAndSelectController` will automatically begin scrolling the table view and will continue selecting / deselecting until the user lifts their finger, pans in the other direction, or reaches the end of the table view.
 
 **Scrolling speed:** You can customize the speed at which the `UITableView` scrolls by changing the `scrollingSpeed` property. By default, it will scroll 20 rows per second.
 
 **Scrolling anchors:** By default, when a pan gesture reaches the top 40 pixels of the table view, the `TableViewScrollAndSelectController` will automatically begin scrolling up. To change this, set the `topScrollingAnchor` property to a custom value. Likewise, by default, when a pan gesture reaches the bottom 40 pixels of the table view, the `TableViewScrollAndSelectController` will automatically begin scrolling down. To change this, set the `bottomScrollingAnchor` property to a custom value. *Note: The bottom anchor needs to be a negative value; by default, the value is -40.0.*
 
 **Estimated row heights:** Using the estimated row height typically minimizes CPU usage, making scrolling more smooth. Unfortunately, if your estimated row heights are not accurate, it may cause some unwanted side effects. These are the most common issues you may experience:
 * The pan gesture does not reach the exact top or bottom of the table view.
 * When the user lifts their finger, the table view scrolls and select a few extra cells before stopping.
 * While scrolling, cells are not being selected / deselected as soon as they come onto screen. This lag becomes more pronounced the longer the scroll animation lasts.
 
 To avoid these issues, make sure to provide an accurate estimated row height or set `shouldUseEstimatedRowHeightWhenScrolling = false`.
 
 ---
 
 # Author
 Will Loderhose
 
 # Copyright
 Copyright © 2018 by Will Loderhose.
 
*/
public class TableViewScrollAndSelectController {
    
    // MARK: - Public Types
    
    /**
     The speed at which the `UITableView` will scroll when a pan gesture reaches the top or bottom edge.
     
     # Scrolling Speeds
     * **fast:** 40 rows per second
     * **moderate:** 20 rows per second
     * **slow:** 10 rows per second
     * **custom:** x rows per second
     */
    public enum ScrollingSpeed {
        /// The `UITableView` will scroll 40 rows per second.
        case fast
        /// The `UITableView` will scroll 20 rows per second.
        case moderate
        /// The `UITableView` will scroll 10 rows per second.
        case slow
        /// The `UITableView` will scroll a custom number of rows per second.
        case custom(rowsPerSecond: Float)
    }
    
    // MARK: - Public Properties
    
    /// The object that acts as the delegate of the `TableViewScrollAndSelectController`.
    public weak var delegate: TableViewScrollAndSelectDelegate?

    /**
     A Boolean value indicating whether the `TableViewScrollAndSelectController` is enabled.
     
     # Default Value
     `false`
     
     - Postcondition: After setting this property to `true`, the touch view will re-layout if needed. After setting this property to `false`, `invalidate()` will be called, and the touch view will be removed from the view hierarchy.
     */
    public var enabled: Bool {
        didSet {
            if !enabled {
                invalidate()
            } else {
                layoutTouchView()
            }
        }
    }
    
    /**
     The width in pixels of the touch view that handles pan gestures.
     
     # Default Value
     `60.0`
     - Postcondition: After changing this property, the touch view will force a re-layout.
    */
    public var touchViewWidth: CGFloat {
        didSet {
            forceLayoutTouchView = true
            layoutTouchView()
        }
    }
    
    /**
     Determines whether the top, left, and bottom edges of the touch view respect safe area margins.
     
     # Default Value
     `false`
     - Postcondition: After changing this property, the touch view will force a re-layout.
     */
    public var touchViewRespectsSafeArea: Bool {
        didSet {
            forceLayoutTouchView = true
            layoutTouchView()
        }
    }
    
    /**
     The point on the y-axis at which a pan gesture should begin scrolling the table view upwards.
     
     # Default Value
     `40.0`
     */
    public var topScrollingAnchor: CGFloat
    
    /**
     The point on the y-axis at which a pan gesture should begin scrolling the table view downwards.
     
     # Default value
     `-40.0`
     - Attention: Value must be <= 0 or no scrolling will occur.
     */
    public var bottomScrollingAnchor: CGFloat
    
    /**
     The speed at which the `UITableView` will scroll when a pan gesture reaches the top or bottom edge.
     
     # Default value
     `ScrollingSpeed.moderate`
     
     # Scrolling speeds
     * **fast:** 40 rows per second
     * **moderate:** 20 rows per second
     * **slow:** 10 rows per second
     * **custom:** x rows per second
    */
    public var scrollingSpeed: ScrollingSpeed
    
    /**
     A Boolean value indicating whether to use the estimated row height of your table view rows to determine scrolling speed and distance.
     
     # Default value
     `true`
     
     - Attention: Using the estimated row height typically minimizes CPU usage, making scrolling more smooth. Unfortunately, if your estimated row heights are not accurate, it may cause some unwanted side effects. These are the most common issues you may experience:
     * The pan gesture does not reach the exact top or bottom of the table view.
     * When the user lifts their finger, the table view scrolls and select a few extra cells before stopping.
     * While scrolling, cells are not being selected / deselected as soon as they come onto screen. This lag becomes more pronounced the longer the scroll animation lasts.
     
     To avoid these issues, make sure to provide an accurate estimated row height or set this property to `false`.
     
     - Remark: The `TableViewScrollAndSelectController` needs to know the height of your table view rows in order to determine the exact speed of the scroll and which cell to stop at when the gesture ends. When this value is set to `true`, it will use the `tableView(_:estimatedHeightForRowAt:)` function of your `UITableViewDelegate`. When set to `false`, it will use the `tableView(_:heightForRowAt:)` function of your `UITableViewDelegate`.
     */
    public var shouldUseEstimatedRowHeightWhenScrolling: Bool
    
    // TODO: Print some logs if in debug mode
    /**
     A Boolean value indiciating whether the `TableViewScrollAndSelectController` is in debug mode.
     
     When debug mode is turned on, the `TableViewScrollAndSelectController` will color its touch view and print out event logs to the console.
     */
    public var isInDebugMode: Bool {
        return debugColor != nil
    }
    
    // MARK: - Private Properties
    
    private weak var tableView: UITableView!
    
    // The touch view is placed over the left side of the table view and receives user tap and pan gestures
    private var touchView: UIView!
    private var forceLayoutTouchView: Bool = true
    
    // A custom set of constraints can be assigned to layout the touch view using a closure.
    // These constraints will be used instead of the default constraints which pin it to the top, left, and bottom edges.
    private var customConstraintClosure: ((_ touchView: UIView) -> [NSLayoutConstraint]?)? {
        didSet {
            forceLayoutTouchView = true
            layoutTouchView()
        }
    }
    
    private var tapGestureRecognizer: UITapGestureRecognizer!
    private var panGestureRecognizer: UIPanGestureRecognizer!
    
    private var debugColor: UIColor?
    
    private var currentPanDetails = PanDetails()
    private var currentScrollDetails = ScrollDetails()
    
    // The timer is used to scroll up or down while selecting or deselecting cells
    private var scrollTimer: Timer?
    
    // MARK: - Initialization
    
    /**
     Initializes and returns a `TableViewScrollAndSelectController` object.
     
     - Parameters:
        - tableView: The `UITableView` for which you want to use scroll and select. The `TableViewScrollAndSelectController` will only retain a weak reference to this table view.
    */
    public init(tableView: UITableView) {
        
        self.tableView = tableView

        enabled = false
        scrollingSpeed = .moderate
        touchViewWidth = 60.0
        topScrollingAnchor = 40.0
        bottomScrollingAnchor = -40.0
        shouldUseEstimatedRowHeightWhenScrolling = true
        touchViewRespectsSafeArea = false
    }
    
    /**
     Initializes and returns a `TableViewScrollAndSelectController` object with a specific scrolling speed.
     
     - Parameters:
        - tableView: The `UITableView` for which you want to use scroll and select. The `TableViewScrollAndSelectController` will only retain a weak reference to this table view.
        - scrollingSpeed: The speed at which the `UITableView` will scroll when a pan gesture reaches the top or bottom edge.
     */
    public convenience init(tableView: UITableView, scrollingSpeed: ScrollingSpeed) {
        
        self.init(tableView: tableView)
        self.scrollingSpeed = scrollingSpeed
    }
    
    // MARK: - Layout
    
    /**
     Set custom constraints for the touch view's layout.
     
     - Parameters:
        - closure: A closure that will run immediately after the touch view is added to the view hierarchy. It will return your custom array of constraints and active them in a batch.
        - touchView: The `UIView` whose constraints you are setting.
     
     - Returns: An optional array of constraints. If the closure returns `nil`, then the default `TableViewScrollAndSelect` constraints will be used.
     
     - Important: You **must** set the constraints of the touch view relative to a view currently in the view hierarchy. It is recommended that you constrain it to `touchView.superview!` which is also the superview of your `UITableView`. This superivew will always be non-nil at the point when your closure is executed.
     
     - Postcondition: After calling this function, the touch view will force a re-layout.

     */
    public func setCustomConstraints(_ closure: @escaping (_ touchView: UIView) -> [NSLayoutConstraint]?) {
        customConstraintClosure = closure
    }
    
    /**
     Clear any custom constraints and force the touch view to re-layout with the `TableViewScrollAndSelect` default constraints.
     
     - Postcondition: After calling this function, the touch view will force a re-layout.
     
     */
    public func clearCustomConstraints() {
        customConstraintClosure = nil
    }
    
    // MARK: - Debug Mode
    
    /**
     Turn debug mode on or off and optionally assign a custom debug color.
     
     When debug mode is turned on, the `TableViewScrollAndSelectController` will color its touch view and print out event logs to the console.
     
     - Parameters:
        - on: A Boolean value indicating whether debug mode is on or off.
        - color: The background color assigned to the touch view when debug mode is on. The default color is `UIColor.green`.
     */
    public func setDebugMode(on: Bool, color: UIColor = .green) {
        
        debugColor = on ? color : nil
        touchView?.backgroundColor = debugColor ?? .clear
    }

    // MARK: - Memory Management
    deinit {
        invalidate()
    }
    
    /**
     Invalidates timers, removes gesture recognizers, removes the touch view from the view hierarchy, and calls `layoutIfNeeded()` on the superview.
     
     This function is automatically called when setting `enabled = false` and during deinitialization of the `TableViewScrollAndSelectController` object.
     */
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
        
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
    
    
}

// MARK: -
// MARK: - Delegate Protocol

/**
 The delegate of a `TableViewScrollAndSelectController` must adopt the `TableViewScrollAndSelectDelegate` protocol. The delegate is notified when the `UITableView` begins and ends scrolling as a result of a scroll and select action.
 
 - Important: To monitor individual row selections, do not use this protocol; instead, override the `tableView(_:DidSelectRowAtIndexPath:)` and `tableView(_:DidDeselectRowAtIndexPath:)` functions in your `UITableViewDelegate`.
 
 ## Delegate Functions
 * `tableViewSelectionPanningDidBegin()`
 * `tableViewSelectionPanningDidEnd()`
 */
public protocol TableViewScrollAndSelectDelegate: class {

    /**
     Called when a pan gesture began over the touch view.
     - Note: This does not necessarily mean that the table view is scrolling. To monitor scrolling, use the `UIScrollViewDelegate` protocol.
    */
    func tableViewSelectionPanningDidBegin()
    
    /**
     Called when a pan gesture ended because the user lifted their finger.
     */
    func tableViewSelectionPanningDidEnd()
}

// MARK: -
// MARK: -
// MARK: - Internal Code
private extension TableViewScrollAndSelectController {
    
    // Convert ScrollingSpeed enum to a Float
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
    
    private enum PanDirection {
        case none
        case down
        case up
    }
    
    private enum PanMode {
        case selecting
        case deselecting
    }
    
    // Package details about the current pan gesture into a single struct
    private struct PanDetails {
        
        var direction: PanDirection = .none
        var mode: PanMode = .selecting
        var position: CGPoint = .zero
        var indexPath: IndexPath?
        
        mutating func switchSelectionMode() {
            mode = mode == .selecting ? .deselecting : .selecting
        }
        
        var isSelecting: Bool {
            return mode == .selecting
        }
    }
    
    // Package details about the current scroll animation into a single struct
    private struct ScrollDetails {
        
        var isScrolling: Bool = false
        var startTime: Date?
        var startOffset: CGPoint?
        var destinationOffset: CGPoint?
        var duration: TimeInterval?
        var startingIndexPath: IndexPath?
        var rowsChanged: Int = 0
    }
    
    // MARK: - Layout
    
    // Add the touch view to the table view's superview, assign auto layout constraints, and add gesture recognizers.
    private func layoutTouchView() {
        
        if tableView.superview == nil || (touchView != nil && touchView.superview != nil && !forceLayoutTouchView) {
            // If the table view is not added to the hierarchy yet, don't configure
            // Likewise, if we've already been layed out, don't layout again unless we want to force it
            return
        }
        
        forceLayoutTouchView = false
        
        // Remove touch view from superview if necessary
        touchView?.removeFromSuperview()
        
        // Initialize the touch view and set its properties
        touchView = UIView()
        touchView.translatesAutoresizingMaskIntoConstraints = false
        touchView.backgroundColor = debugColor ?? .clear
        touchView.alpha = 0.5 // Make partially transparent for debug mode
        
        // Add touch view to table view's superview
        tableView.superview!.addSubview(touchView)
        
        if let closure = customConstraintClosure, let customConstraints = closure(touchView), customConstraints.count > 0 {
            // If custom constraints have been set, use them
            NSLayoutConstraint.activate(customConstraints)
        } else {
            // Otherwise, use the default constraints along with the touchViewWidth and touchViewRespectsSafeArea properties
            
            if touchViewRespectsSafeArea {
                NSLayoutConstraint.activate([
                    touchView.leadingAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.leadingAnchor, constant: -10.0),
                    touchView.trailingAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.leadingAnchor, constant: touchViewWidth),
                    touchView.bottomAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.bottomAnchor, constant: 10.0),
                    touchView.topAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.topAnchor)
                ])
            } else {
                NSLayoutConstraint.activate([
                    touchView.leadingAnchor.constraint(equalTo: tableView.superview!.leadingAnchor, constant: -10.0),
                    touchView.trailingAnchor.constraint(equalTo: tableView.superview!.layoutMarginsGuide.leadingAnchor, constant: touchViewWidth),
                    touchView.bottomAnchor.constraint(equalTo: tableView.superview!.bottomAnchor, constant: 10.0),
                    touchView.topAnchor.constraint(equalTo: tableView.superview!.topAnchor)
                ])
            }
        }
        
        // Make sure touch view is frontmost
        tableView.superview!.bringSubview(toFront: touchView)
        tableView.superview!.layoutIfNeeded()
        
        // Add gesture recognizers
        tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tap))
        tapGestureRecognizer.numberOfTapsRequired = 1
        tapGestureRecognizer.numberOfTouchesRequired = 1
        touchView.addGestureRecognizer(tapGestureRecognizer)
        
        panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan))
        panGestureRecognizer.maximumNumberOfTouches = 1
        panGestureRecognizer.minimumNumberOfTouches = 1
        touchView.addGestureRecognizer(panGestureRecognizer)
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
        // Allow panning over the touch view to trigger scroll and select functionality
        
        if panGestureRecognizer.state == .began {
            // A pan gesture just began
            
            // Notify the delegate
            delegate?.tableViewSelectionPanningDidBegin()
            
            // Refresh panning details
            currentPanDetails = PanDetails()
            
            // Save the new panning position (NOTE: it is relative to the superview not the table view)
            currentPanDetails.position = panGestureRecognizer.location(in: tableView.superview!)
            
            // Select / Deselect current row
            if let indexPath = getIndexPathAtSuperviewPosition(currentPanDetails.position) {
                
                // Remember where the pan started
                currentPanDetails.indexPath = indexPath
                
                // Determine if we are doing a mass selection or deselection
                if let selectedIndexPaths = tableView.indexPathsForSelectedRows, selectedIndexPaths.contains(indexPath) {
                    currentPanDetails.mode = .deselecting
                    changeRowSelection(at: indexPath, select: false)
                } else {
                    currentPanDetails.mode = .selecting
                    changeRowSelection(at: indexPath, select: true)
                }
            }
            
        } else if panGestureRecognizer.state == .changed {
            // The current pan gesture changed position
            
            // Save the new position (NOTE: it is relative to the superview not the table view)
            let newPanningPosition = panGestureRecognizer.location(in: tableView.superview!)
            
            // Don't worry about small changes
            if fabs(newPanningPosition.y - currentPanDetails.position.y) < 5.0 {
                return
            }
            
            // Determine the panning direction and if that direction just changed
            let isPanningDown = newPanningPosition.y > currentPanDetails.position.y
            let directionChanged = (isPanningDown && currentPanDetails.direction == .up) || (!isPanningDown && currentPanDetails.direction == .down)
            
            if currentScrollDetails.isScrolling && !directionChanged {
                // If we are scrolling up or down and the direction of the pan gesture did not change, don't do anything.
                // Just allow the scroll timer to continue scrolling and selecting.
                // We don't even want to save the new position, because we don't want to stop scrolling unless the pan
                // position reaches the point at which it began scrolling.
                // In other words, if the user moves their finger minutely in the opposite direction, don't stop the scroll.
                return
            }
            
            // Save the new position and direction of the pan
            currentPanDetails.position = newPanningPosition
            currentPanDetails.direction = isPanningDown ? .down : .up
            
            guard let indexPath = getIndexPathAtSuperviewPosition(currentPanDetails.position) else {
                return
            }
            
            if directionChanged {
                // The pan direction just changed
                
                if currentScrollDetails.isScrolling {
                    // Stop scrolling
                    currentScrollDetails.isScrolling = false
                    scrollTimer?.invalidate()
                    scrollTimer = nil
                }
                
                // Switch selection mode
                currentPanDetails.switchSelectionMode()
                
                // Update selection for index path that the pan gesture changed direction over
                changeRowSelection(at: indexPath, select: currentPanDetails.isSelecting)
                
                // Remember where the direction change started
                currentPanDetails.indexPath = indexPath
                
            } else if !isAtEdgeOfTableView() {
                // The direction has not changed and we do not need to scroll
                
                // Update selection for index path that the pan gesture just passed over
                if let starting = currentPanDetails.indexPath {
                    
                    // Sometimes, for very fast panning speeds, we need to select multiple cells at a time in order to catch up with the user's finger
                    let rowsMissed: Int
                    if currentPanDetails.direction == .down {
                        rowsMissed = getNumberOfRowsBetween(firstIndexPath: starting, secondIndexPath: indexPath)
                    } else {
                        rowsMissed = getNumberOfRowsBetween(firstIndexPath: indexPath, secondIndexPath: starting)
                    }
                    if rowsMissed > 1 {
                        changeRowSelection(from: indexPath,
                                           numberOfRows: rowsMissed,
                                           select: currentPanDetails.isSelecting,
                                           direction: currentPanDetails.direction)
                    } else {
                        changeRowSelection(at: indexPath, select: currentPanDetails.isSelecting)
                    }
                }
                
                // Update the current indexPath so we know which rows have been correctly selected / deselected
                currentPanDetails.indexPath = indexPath
                
            } else {
                // We have reached the top or bottom edge of the table view - we need to begin scrolling
                
                // Refresh the scrolling details
                currentScrollDetails = ScrollDetails()
                currentScrollDetails.isScrolling = true
                
                // Remember which index path the scrolling began at
                currentScrollDetails.startingIndexPath = indexPath
                
                // Get the current content offset
                currentScrollDetails.startOffset = tableView.contentOffset
                
                // Compute the destination offset in order to reach the very end of the table view
                let destinationIndexPath: IndexPath?
                
                if currentPanDetails.direction == .down {
                    currentScrollDetails.destinationOffset = CGPoint(x: tableView.contentOffset.x, y: tableView.contentSize.height - tableView.bounds.height)
                    destinationIndexPath = getLastIndexPath()
                } else {
                    currentScrollDetails.destinationOffset = CGPoint(x: tableView.contentOffset.x, y: -tableView.safeAreaInsets.top)
                    destinationIndexPath = getFirstIndexPath()
                }
                
                if let destination = destinationIndexPath {
                    
                    // Determine how many rows we need to scroll to the top/bottom
                    let rowsToScroll: Float
                    if currentPanDetails.direction == .down {
                        rowsToScroll = Float(getNumberOfRowsBetween(firstIndexPath: indexPath, secondIndexPath: destination))
                    } else {
                        rowsToScroll = Float(getNumberOfRowsBetween(firstIndexPath: destination, secondIndexPath: indexPath))
                    }
                    
                    // Remember the start time of the scroll
                    currentScrollDetails.startTime = Date()
                    
                    // Compute the total duration needed to scroll to the top/bottom
                    currentScrollDetails.duration = TimeInterval(rowsToScroll * scrollAnimationDuration)
                    
                    // Start the timer
                    scrollTimer = Timer.scheduledTimer(timeInterval: 0.001,
                                                       target: self,
                                                       selector: #selector(scrollAndSelect),
                                                       userInfo: nil,
                                                       repeats: true)
                }
            }
            
        } else if panGestureRecognizer.state == .ended || panGestureRecognizer.state == .cancelled {
            // The user lifted their finger from a pan gesture
            
            // End the scrolling animation and timer
            currentScrollDetails.isScrolling = false
            scrollTimer?.invalidate()
            scrollTimer = nil
            
            // Notify delegate
            delegate?.tableViewSelectionPanningDidEnd()
        }
    }
    
    @objc private func scrollAndSelect() {
        // Called by the panning timer every 0.001 seconds during a scroll and select animation
        
        if !currentScrollDetails.isScrolling {
            // Stop scrolling if something user lifted their finger or we got invalidated for any reason
            scrollTimer?.invalidate()
            scrollTimer = nil
            return
        }
        
        let timeRunning: TimeInterval = -currentScrollDetails.startTime!.timeIntervalSinceNow
        
        // If we're using estimated row heights, the destiation offset has already been calculated when we started the scroll
        // Otherwise, we have to calculate the destination offset each time we reach a new row
        let destinationOffset: CGPoint
        if shouldUseEstimatedRowHeightWhenScrolling {
            destinationOffset = currentScrollDetails.destinationOffset!
        } else if currentPanDetails.direction == .down {
            destinationOffset = CGPoint(x: tableView.contentOffset.x, y: tableView.contentSize.height - tableView.bounds.height)
        } else {
            destinationOffset = CGPoint(x: tableView.contentOffset.x, y: -tableView.safeAreaInsets.top)
        }
        
        // Determine how many rows have been passed so that we can select / deselect them
        let rowsPassed = Int(timeRunning / Double(scrollAnimationDuration)) + 1
        if rowsPassed >= currentScrollDetails.rowsChanged {
            
            // We reached a new index path - time to select / deselect it and any others we may have missed
            if let selectionFromIndexPath = getIndexPathOffsetFrom(indexPath: currentPanDetails.indexPath!,
                                                                        by: currentScrollDetails.rowsChanged * (currentPanDetails.direction == .down ? 1 : -1)) {
                
                changeRowSelection(from: selectionFromIndexPath,
                                   numberOfRows: rowsPassed - currentScrollDetails.rowsChanged,
                                   select: currentPanDetails.isSelecting,
                                   direction: currentPanDetails.direction)
                
                currentScrollDetails.rowsChanged = rowsPassed
            }
        }
        
        if timeRunning >= currentScrollDetails.duration! {
            // We made it to the end of the table view
            
            // Select / deselect any cells we may have missed
            changeRowSelection(at: currentPanDetails.direction == .down ? getLastIndexPath()! : getFirstIndexPath()!,
                               select: currentPanDetails.isSelecting)
            
            // Scroll the table view to the very edge
            tableView.setContentOffset(destinationOffset, animated: false)
            
            // Stop timer
            scrollTimer?.invalidate()
            scrollTimer = nil
            
        } else {
            // We have not yet reached the end of the table view
            
            let distanceTraveled: CGFloat
            let newOffset: CGPoint
            
            // Calculate how far we have traveled and how far the next scroll should take us
            if currentPanDetails.direction == .down {
                distanceTraveled = (destinationOffset.y - currentScrollDetails.startOffset!.y) * CGFloat(timeRunning / currentScrollDetails.duration!)
                newOffset = CGPoint(x: tableView.contentOffset.x, y: currentScrollDetails.startOffset!.y + distanceTraveled)
            } else {
                distanceTraveled = fabs(currentScrollDetails.startOffset!.y - currentScrollDetails.destinationOffset!.y) * CGFloat(timeRunning / currentScrollDetails.duration!)
                newOffset = CGPoint(x: tableView.contentOffset.x, y: currentScrollDetails.startOffset!.y - distanceTraveled)
            }
            
            // Scroll the tableview
            tableView.setContentOffset(newOffset, animated: false)
        }
        
    }
    
    // MARK: - Helper Functions
    
    // Convert a CGPoint relative to the superview to a CGPoint relative to the table view and then grab the index path at that point
    private func getIndexPathAtSuperviewPosition(_ superviewPosition: CGPoint) -> IndexPath? {
        return tableView.indexPathForRow(at: tableView.superview!.convert(superviewPosition, to: tableView))
    }
    
    // Calculate the number of rows between two index paths
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
    
    // Get the first index path in the table view
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
    
    // Get the last index path in the table view
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
    
    // Find an index path in the table view offset from a give index path by a specific number of rows
    private func getIndexPathOffsetFrom(indexPath: IndexPath, by offset: Int) -> IndexPath? {
        
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
    
    // Change the selection of multiple rows in the table view
    private func changeRowSelection(from fromIndexPath: IndexPath, numberOfRows: Int, select: Bool, direction: PanDirection) {
        
        var indexPath = fromIndexPath
        var count = 0
        while count < numberOfRows {
            
            changeRowSelection(at: indexPath, select: select)
            if let nextIndexPath = getIndexPathOffsetFrom(indexPath: indexPath, by: direction == .down ? 1 : -1) {
                indexPath = nextIndexPath
            } else {
                return
            }
            
            count += 1
        }
    }
    
    // Change the selection of one row in the table view and notify the UITableViewDelegate
    private func changeRowSelection(at indexPath: IndexPath, select: Bool) {
        
        if select && (tableView.indexPathsForSelectedRows == nil || !tableView.indexPathsForSelectedRows!.contains(indexPath)) {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
        } else if !select && (tableView.indexPathsForSelectedRows != nil && tableView.indexPathsForSelectedRows!.contains(indexPath)) {
            tableView.deselectRow(at: indexPath, animated: true)
            tableView.delegate?.tableView?(tableView, didDeselectRowAt: indexPath)
        }
    }
    
    // Calculate if the current pan gesture has reached the edge of the table view or not
    private func isAtEdgeOfTableView() -> Bool {
        
        let superviewRect = UIEdgeInsetsInsetRect(tableView.superview!.frame, tableView.safeAreaInsets)
        if currentPanDetails.direction == .down {
            return currentPanDetails.position.y > (superviewRect.origin.y + superviewRect.height) + bottomScrollingAnchor
        } else {
            return currentPanDetails.position.y < superviewRect.origin.y + topScrollingAnchor
        }
    }
}
