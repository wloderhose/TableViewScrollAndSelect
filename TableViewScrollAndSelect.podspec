#
# Be sure to run `pod lib lint TableViewScrollAndSelect.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'TableViewScrollAndSelect'
  s.version          = '1.0.0'
  s.summary          = 'Simultaneously scroll and select cells in a UITableView in response to simple pan gestures.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
Have you ever wished UITableView made it easier to select more than one cell at a time? TableViewScrollAndSelect improves the default functionality of UITableView to allow multiple selection of cells and automatic scrolling using simple pan gestures.
                       DESC

  s.homepage         = 'https://github.com/wloderhose/TableViewScrollAndSelect'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'wloderhose' => 'wloderhose@gmail.com' }
  s.source           = { :git => 'https://github.com/wloderhose/TableViewScrollAndSelect.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'

  s.source_files = 'TableViewScrollAndSelect/Classes/**/*'
  s.frameworks = 'UIKit'
end
