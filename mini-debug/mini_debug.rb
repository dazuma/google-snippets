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
      @breakpoints << Breakpoint.new(name, file, line)
    end

    def delete_breakpoint name
      @breakpoints.delete_if{ |b| b.name == name }
    end

    def cont irb_context
      @stepping = false
      irb_context.exit
    end

    def step_over irb_context
      @target_depth = @depth
      irb_context.exit
    end

    def step_in irb_context
      @target_depth = @depth + 1
      irb_context.exit
    end

    def step_out irb_context
      @target_depth = @depth - 1
      irb_context.exit
    end

    def start
      @breakpoints = []
      @stepping = false
      @depth = 0
      create_break_tracepoint
      create_depth_tracepoints
    end

    private

    def create_break_tracepoint
      TracePoint.trace :line do |tp|
        bp = @breakpoints.find{ |b| b.file == tp.path && b.line == tp.lineno }
        if bp
          puts "**** Hit breakpoint: #{bp.name} ****"
          @stepping = true
          @target_depth = @depth
        end
        if @stepping && @depth <= @target_depth
          puts "**** At #{tp.defined_class}##{tp.method_id} (#{tp.path}:#{tp.lineno})"
          tp.binding.irb
        end
      end
    end

    def create_depth_tracepoints
      TracePoint.trace :call, :b_call { |tp| @depth += 1 }
      TracePoint.trace :return, :b_return { |tp| @depth -= 1 }
    end

  end
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

MiniDebug.start
