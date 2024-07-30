def tick(args)
  state = args.state
  state.current_slide_index ||= 0

  handle_input(args)

  current_slide = state.presentation[:slides][state.current_slide_index]
  render_slide(args, current_slide)
  render_slide_progress(args, state.current_slide_index, state.presentation[:slides].length)
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

def render_slide_progress(args, current_slide_index, slide_count)
  bar_base = { x: 0, y: 0, h: 10, path: :pixel }
  args.outputs.sprites << bar_base.merge(w: 1280, r: 150, g: 150, b: 150)
  progress_color = { r: 0, g: 150, b: 0 }
  args.outputs.sprites << bar_base.merge(w: 1280 * (current_slide_index + 1) / slide_count, **progress_color)
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
