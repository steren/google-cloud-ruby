# Copyright 2016 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require "helper"

describe Stackdriver do
  it "requires google-cloud-error_reporting" do
    defined?(Google::Cloud::ErrorReporting).wont_be_nil
  end

  it "requires google-cloud-logging" do
    defined?(Google::Cloud::Logging).wont_be_nil
  end

  it "requires google-cloud-monitoring" do
    defined?(Google::Cloud::Monitoring).wont_be_nil
  end

  it "requires google-cloud-error_reporting rails module" do
    defined?(Google::Cloud::ErrorReporting::Railtie).wont_be_nil
  end

  it "requires google-cloud-logging rails module" do
    defined?(Google::Cloud::Logging::Railtie).wont_be_nil
  end
end
