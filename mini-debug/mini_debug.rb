# Copyright 2017 Google Inc.
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


require "irb"

module MiniDebug
  Breakpoint = Struct.new :name, :file, :line

  class << self

    def add_breakpoint name, file, line
      @break_tracepoint.enable if @breakpoints.empty?
      @breakpoints << Breakpoint.new(name, file, line)
      self
    end

    def delete_breakpoint name
      @breakpoints.delete_if{ |b| b.name == name }
      @break_tracepoint.disable if @breakpoints.empty?
      self
    end

    def cont irb_context
      @stepping = false
      @depth_tracepoint.disable
      irb_context.exit
    end

    def step_over irb_context
      @step_depth = 0
      irb_context.exit
    end

    def step_in irb_context
      @step_depth = -1
      irb_context.exit
    end

    def step_out irb_context
      @step_depth = 1
      irb_context.exit
    end

    private

    def start
      @breakpoints = []
      create_break_tracepoint
      @stepping = false
      @step_depth = 0
      create_depth_tracepoint
      self
    end

    def create_break_tracepoint
      @break_tracepoint = TracePoint.new :line do |tp|
        b = @breakpoints.find{ |b| tp.path == b.file && tp.lineno == b.line }
        if b
          puts "**** Hit breakpoint: #{b.name} ****"
          @stepping = true
          @step_depth = 0
          @depth_tracepoint.enable unless @depth_tracepoint.enabled?
        end
        if @stepping && @step_depth <= 0
          puts "**** Breaking at #{tp.defined_class}##{tp.callee_id} (#{tp.path}:#{tp.lineno}) ****"
          tp.binding.irb
        end
      end
    end

    def create_depth_tracepoint
      @depth_tracepoint = TracePoint.new :call, :b_call, :return, :b_return do |tp|
        if tp.event.to_s.end_with? "return"
          @step_depth -= 1
        else
          @step_depth += 1
        end
      end
    end

  end

  start
end


module IRB::ExtendCommandBundle
  def cont
    MiniDebug.cont irb_context
  end

  def step_over
    MiniDebug.step_over irb_context
  end

  def step_in
    MiniDebug.step_in irb_context
  end

  def step_out
    MiniDebug.step_out irb_context
  end
end
