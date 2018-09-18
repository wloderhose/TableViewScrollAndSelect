//
//  ExampleSettingsViewController.swift
//  TableViewScrollAndSelect_Example
//
//  Created by Will Loderhose on 8/31/18.
//  Copyright © 2018 CocoaPods. All rights reserved.
//

import TableViewScrollAndSelect

protocol ExampleSettingsViewDelegate: class {
    
    func settingsDidChangeSectionCount(count: Int)
    func settingsDidChangeRowCount(count: Int)
    func settingsDidChangeScrollingSpeed(speed: TableViewScrollAndSelectController.ScrollingSpeed)
    func settingsCurrentSectionCount() -> Int
    func settingsCurrentRowCount() -> Int
    func settingsCurrentScrollingSpeed() -> TableViewScrollAndSelectController.ScrollingSpeed
}

class ExampleSettingsViewController: UIViewController {
    
    // MARK: - Properties
    weak var delegate: ExampleSettingsViewDelegate!
    
    @IBOutlet weak var sectionsPickerView: UIPickerView!
    @IBOutlet weak var rowsPickerView: UIPickerView!
    @IBOutlet weak var speedSegmentedControl: UISegmentedControl!
    @IBOutlet weak var customSpeedLabel: UILabel!
    @IBOutlet weak var customSpeedPickerView: UIPickerView!
    
    // MARK: - Load
    override func viewDidLoad() {
        super.viewDidLoad()

        sectionsPickerView.selectRow(delegate!.settingsCurrentSectionCount() - 1, inComponent: 0, animated: false)
        rowsPickerView.selectRow(delegate!.settingsCurrentRowCount() - 1, inComponent: 0, animated: false)
        
        switch delegate!.settingsCurrentScrollingSpeed() {
        case .slow:
            speedSegmentedControl.selectedSegmentIndex = 0
            customSpeedPickerView.selectRow(40 * 4 - 1, inComponent: 0, animated: false)

        case .moderate:
            speedSegmentedControl.selectedSegmentIndex = 1
            customSpeedPickerView.selectRow(20 * 4 - 1, inComponent: 0, animated: false)

        case .fast:
            speedSegmentedControl.selectedSegmentIndex = 2
            customSpeedPickerView.selectRow(10 * 4 - 1, inComponent: 0, animated: false)

        case .custom(let rowsPerSecond):
            speedSegmentedControl.selectedSegmentIndex = 3
            customSpeedPickerView.selectRow(Int(rowsPerSecond * 4 - 1), inComponent: 0, animated: false)
        }
        
        updateEnabledState()
    }
    
    // MARK: - Actions
    @IBAction func scrollingSpeedChanged(_ sender: Any) {
        
        let speed: TableViewScrollAndSelectController.ScrollingSpeed
        if speedSegmentedControl.selectedSegmentIndex == 0 {
            speed = .slow
        } else if speedSegmentedControl.selectedSegmentIndex == 1 {
            speed = .moderate
        } else if speedSegmentedControl.selectedSegmentIndex == 2 {
            speed = .fast
        } else {
            speed = .custom(rowsPerSecond: (Float(customSpeedPickerView.selectedRow(inComponent: 0)) + 1) / 4)
        }
        
        delegate!.settingsDidChangeScrollingSpeed(speed: speed)
        updateEnabledState()
    }
    
    private func updateEnabledState() {
        
        switch delegate!.settingsCurrentScrollingSpeed() {
            
        case .slow:
            customSpeedPickerView.selectRow(10 * 4 - 1, inComponent: 0, animated: false)
            customSpeedLabel.alpha = 0.5
            customSpeedPickerView.isUserInteractionEnabled = false
            customSpeedPickerView.alpha = 0.5
            
        case .moderate:
            customSpeedPickerView.selectRow(20 * 4 - 1, inComponent: 0, animated: false)
            customSpeedLabel.alpha = 0.5
            customSpeedPickerView.isUserInteractionEnabled = false
            customSpeedPickerView.alpha = 0.5
            
        case .fast:
            customSpeedPickerView.selectRow(40 * 4 - 1, inComponent: 0, animated: false)
            customSpeedLabel.alpha = 0.5
            customSpeedPickerView.isUserInteractionEnabled = false
            customSpeedPickerView.alpha = 0.5
            
        case .custom(let rowsPerSecond):
            customSpeedLabel.alpha = 1.0
            customSpeedPickerView.isUserInteractionEnabled = true
            customSpeedPickerView.alpha = 1.0
            customSpeedPickerView.selectRow(Int(rowsPerSecond * 4 - 1), inComponent: 0, animated: false)
        }
    }

}

// MARK: - Picker View data source / delegate
extension ExampleSettingsViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        if pickerView === sectionsPickerView {
            delegate!.settingsDidChangeSectionCount(count: row + 1)
        } else if pickerView === rowsPickerView {
            delegate!.settingsDidChangeRowCount(count: row + 1)
        } else {
            delegate!.settingsDidChangeScrollingSpeed(speed: .custom(rowsPerSecond: Float(row + 1) / 4))
        }
        
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        
        if pickerView == customSpeedPickerView {
            return "\(Double(row) / 4 + 0.25)"
        } else {
            return "\(row + 1)"
        }
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
       
        if pickerView === sectionsPickerView {
            return 20
        } else if pickerView === rowsPickerView {
            return 100
        } else {
            return 200
        }
    }
    
}
