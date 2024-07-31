def tick(args)
  start_highlight_server_if_needed
  state = args.state
  state.timer ||= { state: :stopped }
  state.current_slide_index ||= 0

  handle_input(args)

  current_slide = state.presentation[:slides][state.current_slide_index]
  render_slide(args, current_slide)
  render_slide_progress(args)
end

def handle_input(args)
  key_down = args.inputs.keyboard.key_down

  next_slide if key_down.enter || key_down.space || key_down.right

  previous_slide if key_down.left
end

def next_slide
  slide_count = $state.presentation[:slides].length
  $state.current_slide_index = [$state.current_slide_index + 1, slide_count - 1].min
end

def previous_slide
  $state.current_slide_index = [$state.current_slide_index - 1, 0].max
end

def start_timer
  $state.timer[:state] = :running
  $state.timer[:start_time] = Time.now
end

def render_slide(args, slide)
  y = 700
  slide[:elements].each do |element|
    case element[:type]
    when :title
      args.outputs.labels << {
        x: 640, y: y, text: element[:text],
        size_enum: 20, alignment_enum: 1
      }
      y -= 80
    when :subtitle
      args.outputs.labels << {
        x: 640, y: y, text: element[:text],
        size_enum: 10, alignment_enum: 1
      }
      y -= 40
    when :list
      element[:items].each do |item|
        args.outputs.labels << {
          x: 20, y: y, text: "・ #{item}",
          size_enum: 12
        }
        y -= 50
      end
    end
  end
end

def start_highlight_server_if_needed
  return if $highlight_server_pid

  $highlight_server_pid = `node #{$gtk.get_game_dir}/syntax-highlighting > /dev/null & echo $!`
  log "Started highlight server with PID #{$highlight_server_pid}"
end

ON_TIME_COLOR = { r: 0, g: 150, b: 0 }
LATE_COLOR = { r: 150, g: 0, b: 0 }

def render_slide_progress(args)
  current_slide_index = args.state.current_slide_index
  slide_count = args.state.presentation[:slides].length
  progress = (current_slide_index + 1) / slide_count

  bar_base = { x: 0, y: 0, h: 10, path: :pixel }
  args.outputs.sprites << bar_base.merge(w: 1280, r: 150, g: 150, b: 150)


  timer = args.state.timer
  time_progress = 0

  if timer[:state] == :running
    time_progress = [(Time.now - timer[:start_time]) / args.state.presentation[:time_limit], 1].min
  end
  progress_color = time_progress <= progress ? ON_TIME_COLOR : LATE_COLOR

  args.outputs.sprites << bar_base.merge(w: 1280 * progress, **progress_color)
  args.outputs.sprites << bar_base.merge(y: 10, h: 5, w: 1280 * time_progress, r: 128, g: 128, b: 128)
end

module SliDR
  def self.present(&block)
    $state.presentation = {
      slides: []
    }
    PresentationDSL.new($state.presentation).instance_exec(&block)
  end

  class PresentationDSL
    def initialize(presentation)
      @presentation = presentation
    end

    def slide(&block)
      slide = { elements: [] }
      SlideDSL.new(slide).instance_exec(&block)
      @presentation[:slides] << slide
    end

    def time_limit(minutes:)
      @presentation[:time_limit] = minutes * 60
    end
  end

  class SlideDSL
    def initialize(slide)
      @slide = slide
      @elements = @slide[:elements]
    end

    def title(text)
      @elements << { type: :title, text: text }
    end

    def subtitle(text)
      @elements << { type: :subtitle, text: text }
    end

    def list(&block)
      list = []
      ListDSL.new(list).instance_exec(&block)
      @elements << { type: :list, items: list }
    end
  end

  class ListDSL
    def initialize(list)
      @list = list
    end

    def item(text)
      @list << text
    end
  end
end
