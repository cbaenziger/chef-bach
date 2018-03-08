copylogs Cookbook
===============
Cookbook to deploy a means for centralizing logs files and copying them to HDFS

Usage
-----
Pre-reqs: Java, maven and git are installed.

1. Include `recipe[copylogs::build.rb]` to build Apache Flume.
4. Include `recipe[copylogs::copylogs]` to configure Flume for all desired log files

License and Authors
-------------------
Copyright 2018, Bloomberg L.P.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this cookbook except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
