def tick(args)
  start_highlight_server_if_needed
  prepare_slides(args)

  state = args.state
  state.timer ||= { state: :stopped }
  state.current_slide_index ||= 0

  handle_input(args)

  current_slide = state.presentation[:slides][state.current_slide_index]
  render_slide(args, current_slide)
  render_slide_progress(args)
end

def start_highlight_server_if_needed
  return if $highlight_server_pid

  $highlight_server_pid = `node #{$gtk.get_game_dir}/syntax-highlighting > /dev/null & echo $!`
  log "Started highlight server with PID #{$highlight_server_pid}"
end

def prepare_slides(args)
  presentation = args.state.presentation
  return if presentation[:prepared]

  presentation[:slides].each do |slide|
    next if slide[:prepared]

    if slide[:preparation_tasks]
      handle_preparation_tasks(args, slide)
    else
      slide[:preparation_tasks] = []
      slide[:elements].each do |element|
        case element[:type]
        when :code_block
          slide[:preparation_tasks] << {
            type: :highlight_code,
            finished: false,
            element: element
          }
        end
      end
    end
  end

  presentation[:prepared] = presentation[:slides].all? { |slide| slide[:prepared] }
end

def handle_preparation_tasks(args, slide)
  slide[:preparation_tasks].each do |task|
    next if task[:finished]

    send("prepare_slide_#{task[:type]}", args, task)
  end
  slide[:prepared] = slide[:preparation_tasks].all? { |task| task[:finished] }
end

def prepare_slide_highlight_code(args, task)
  if task[:request]
    request = task[:request]
    return unless request[:complete]

    case request[:http_response_code]
    when 200
      response = $gtk.parse_json(request[:response_data])
      task[:element][:labels] = build_code_labels(response['highlightedCode'])
      task[:finished] = true
    when -1
      task.delete(:request)
    end
  else
    element = task[:element]
    task[:request] = $gtk.http_post_body(
      'http://localhost:9002/highlight',
      '{"language":"' + element[:language] + '","code":' + element[:code].inspect + '}',
      ['Content-Type: application/json']
    )
  end
end

def build_code_labels(highlight_node, cursor = nil)
  cursor ||= { x: 0, y: 0 }

  case highlight_node['type']
  when 'root'
    highlight_node['children'].map { |child|
      build_code_labels(child, cursor)
    }.flatten
  when 'text'
    value = highlight_node['value']
    lines = value.split("\n")

    labels = []

    if lines.length > 0
      first_line = lines.shift

      new_label = normal_text_label(first_line, cursor)
      advance_cursor(cursor, first_line)
      new_label[:right] = cursor[:x]
      labels << new_label

      lines.each do |line|
        advance_cursor_to_next_line(cursor)
        new_label = normal_text_label(line, cursor)
        advance_cursor(cursor, line)
        new_label[:right] = cursor[:x]
        labels << new_label
      end
    end

    advance_cursor_to_next_line(cursor) if value.end_with?("\n")

    labels
  when 'element'
    labels = highlight_node['children'].map { |child|
      build_code_labels(child, cursor)
    }.flatten
    color = get_code_color(highlight_node['properties']['className'][0])
    labels.each { |label| label.merge!(color) }
    labels
  end
end

def normal_text_label(text, cursor)
  {
    x: cursor[:x], y: cursor[:y], text: text,
    r: 230, g: 237, b: 243,
    size_enum: 6
  }
end

def advance_cursor(cursor, text)
  text_width = $gtk.calcstringbox(text, size_enum: 6)[0]
  cursor[:x] += text_width
end

def advance_cursor_to_next_line(cursor)
  cursor[:x] = 0
  cursor[:y] -= 35
end

def get_code_color(class_name)
  case class_name
  when 'pl-k'
    { r: 0xff, g: 0x7b, b: 0x72 }
  when 'pl-en'
    { r: 0xd2, g: 0xa8, b: 0xff }
  when 'pl-smi'
    { r: 0xc9, g: 0xd1, b: 0xd9 }
  when 'pl-c1'
    { r: 0x79, g: 0xc0, b: 0xff }
  else
    log "Unknown class name: #{class_name}"
    {}
  end
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
    when :code_block
      y -= 50
      top = y + 20
      if element[:labels]
        rendered_labels = element[:labels].map { |label|
          {
            x: 50 + label[:x], y: y + label[:y], text: label[:text],
            size_enum: 6, r: label[:r], g: label[:g], b: label[:b],
            right: 50 + label[:right]
          }
        }
        args.outputs.labels << rendered_labels
        right = rendered_labels.map { |label| label[:right] }.max
        bottom = rendered_labels.map { |label| label[:y] }.min - 35 - 20

        args.outputs.sprites << {
          x: 30, y: bottom, w: right, h: top - bottom, path: :pixel,
          r: 22, g: 27, b: 34
        }

        y = bottom - 20
      else
        args.outputs.labels << {
          x: 640, y: y, text: 'Loading...',
          size_enum: 12
        }
        y -= 20
      end
    end
  end
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

    def code_block(language, code)
      @elements << { type: :code_block, language: language, code: code }
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
