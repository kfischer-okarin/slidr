def tick(args)
  state = args.state
  state.current_slide_index ||= 0

  current_slide = state.presentation[:slides][state.current_slide_index]
  render_slide(args, current_slide)
end

def render_slide(args, slide)
  y = 700
  slide[:elements].each do |element|
    case element[:type]
    when :title
      args.outputs.labels << {
        x: 640, y: y, text: element[:text],
        size_enum: 10, alignment_enum: 1
      }
      y -= 50
    when :subtitle
      args.outputs.labels << {
        x: 640, y: y, text: element[:text],
        size_enum: 5, alignment_enum: 1
      }
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
  end
end
