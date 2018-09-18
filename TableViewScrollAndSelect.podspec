#
#  TableViewScrollAndSelectController.podspec
#  TableViewScrollAndSelect
#
#  Created by Will Loderhose on 8/31/2018.
#  Copyright © 2018 CocoaPods. All rights reserved.
#

Pod::Spec.new do |s|
  s.name             = 'TableViewScrollAndSelect'
  s.version          = '1.0.0'
  s.summary          = 'Elegant multi-selection for UITableView'

  s.description      = <<-DESC
TableViewScrollAndSelect provides a simple, elegant solution to multiple row selection in a UITableView. It was designed to deliver an excellent user experience while requiring very little setup - nothing more than a few lines of code in your UITableViewController.
                       DESC

  s.homepage         = 'https://github.com/wloderhose/TableViewScrollAndSelect'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wloderhose' => 'wloderhose@gmail.com' }
  s.source           = { :git => 'https://github.com/wloderhose/TableViewScrollAndSelect.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'
  s.swift_version    = '4.0'

  s.source_files = 'TableViewScrollAndSelect/Classes/**/*'
  s.frameworks = 'UIKit'
end
