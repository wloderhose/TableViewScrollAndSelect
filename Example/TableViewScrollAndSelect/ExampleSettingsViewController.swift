//
//  ExampleSettingsViewController.swift
//  TableViewScrollAndSelect_Example
//
//  Created by Will Loderhose on 9/5/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import UIKit
import TableViewScrollAndSelect

protocol ExampleSettingsViewDelegate: class {
    
    func settingsDidChangeSectionCount(count: Int)
    func settingsDidChangeRowCount(count: Int)
    func settingsDidChangeScrollingSpeed(speed: UITableViewScrollAndSelectController.ScrollingSpeed)
    func settingsCurrentSectionCount() -> Int
    func settingsCurrentRowCount() -> Int
    func settingsCurrentScrollingSpeed() -> UITableViewScrollAndSelectController.ScrollingSpeed
}

class ExampleSettingsViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: ExampleSettingsViewDelegate!
    
    @IBOutlet weak var sectionsPickerView: UIPickerView!
    @IBOutlet weak var rowsPickerView: UIPickerView!
    @IBOutlet weak var speedSegmentedControl: UISegmentedControl!
    @IBOutlet weak var customSpeedLabel: UILabel!
    @IBOutlet weak var customSpeedPickerView: UIPickerView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        sectionsPickerView.selectRow(delegate!.settingsCurrentSectionCount() - 1, inComponent: 0, animated: false)
        rowsPickerView.selectRow(delegate!.settingsCurrentRowCount() - 1, inComponent: 0, animated: false)
        
        switch delegate!.settingsCurrentScrollingSpeed() {
        case .slow:
            speedSegmentedControl.selectedSegmentIndex = 0
            customSpeedPickerView.selectRow(39, inComponent: 0, animated: false)

        case .moderate:
            speedSegmentedControl.selectedSegmentIndex = 1
            customSpeedPickerView.selectRow(19, inComponent: 0, animated: false)

        case .fast:
            speedSegmentedControl.selectedSegmentIndex = 2
            customSpeedPickerView.selectRow(9, inComponent: 0, animated: false)

        case .custom(let rowsPerSecond):
            speedSegmentedControl.selectedSegmentIndex = 3
            customSpeedPickerView.selectRow(Int(rowsPerSecond - 1), inComponent: 0, animated: false)
        }
        
        updateEnabledState()
    }
    
    @IBAction func scrollingSpeedChanged(_ sender: Any) {
        
        let speed: UITableViewScrollAndSelectController.ScrollingSpeed
        if speedSegmentedControl.selectedSegmentIndex == 0 {
            speed = .slow
        } else if speedSegmentedControl.selectedSegmentIndex == 1 {
            speed = .moderate
        } else if speedSegmentedControl.selectedSegmentIndex == 2 {
            speed = .fast
        } else {
            speed = .custom(rowsPerSecond: Float(customSpeedPickerView.selectedRow(inComponent: 0)) + 1)
        }
        
        delegate!.settingsDidChangeScrollingSpeed(speed: speed)
        updateEnabledState()
    }
    
    private func updateEnabledState() {
        
        switch delegate!.settingsCurrentScrollingSpeed() {
        case .custom(let rowsPerSecond):
            customSpeedLabel.alpha = 1.0
            customSpeedPickerView.isUserInteractionEnabled = true
            customSpeedPickerView.alpha = 1.0
            customSpeedPickerView.selectRow(Int(rowsPerSecond - 1), inComponent: 0, animated: false)
        default:
            if delegate!.settingsCurrentScrollingSpeed() == .slow {
                customSpeedPickerView.selectRow(9, inComponent: 0, animated: false)
            } else if delegate!.settingsCurrentScrollingSpeed() == .moderate {
                customSpeedPickerView.selectRow(19, inComponent: 0, animated: false)
            } else {
                customSpeedPickerView.selectRow(39, inComponent: 0, animated: false)
            }
            customSpeedLabel.alpha = 0.5
            customSpeedPickerView.isUserInteractionEnabled = false
            customSpeedPickerView.alpha = 0.5
        }
    }

}

extension ExampleSettingsViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        if pickerView === sectionsPickerView {
            delegate!.settingsDidChangeSectionCount(count: row + 1)
        } else if pickerView === rowsPickerView {
            delegate!.settingsDidChangeRowCount(count: row + 1)
        } else {
            delegate!.settingsDidChangeScrollingSpeed(speed: .custom(rowsPerSecond: Float(row + 1)))
        }
        
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(row + 1)"
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 300
    }
    
}
