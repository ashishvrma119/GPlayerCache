Pod::Spec.new do |s|
  s.name         = "GPlayerCache"
  s.version      = "1.0.3"
  s.summary      = "A caching library for GPlayerCache."
  s.description  = "AVGPlayerCache is a library that provides caching functionality for GPlayerCache. It allows developers to cache video files locally for efficient playback and reduces network usage."
  s.homepage     = "https://github.com/ashishvrma119/GPlayerCache"
  s.license      = { :type => 'MIT', :text => 'Copyright (c) 2024

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:
  
  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.
  
  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.' }
  s.author       = { 'GPlayerCache' => '“ashishvrma119@gmail.com”' }
  s.platform     = :ios, "14.0"
  s.ios.deployment_target = "14.0"
  s.swift_version = "5.1"

  s.source       = { :git => "https://github.com/ashishvrma119/GPlayerCache.git", :tag => s.version.to_s }
  s.source_files  = "GPlayerCache/**/*.{h,m,swift}"
  

end
