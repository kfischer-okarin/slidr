def tick(args)
  state = args.state
  state.current_slide_index ||= 0

  handle_input(args)

  current_slide = state.presentation[:slides][state.current_slide_index]
  render_slide(args, current_slide)
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
