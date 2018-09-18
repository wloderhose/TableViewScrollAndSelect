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

  s.description      = <<-DESC
Transform a normal UITableView into a snazzy one by allowing users to pan up and down in order to quickly select multiple cells, and scroll the view as they go.
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
