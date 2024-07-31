require 'lib/slidr'

SliDR.present do
  time_limit minutes: 2

  slide do
    title 'Hello, SliDR!'
    subtitle 'A simple DSL for creating slides'
  end

  slide do
    title 'Features'
    list do
      item 'Simple DSL'
      item 'Easy to use'
      item 'Extensible'
    end

    code_block('ruby', <<~RUBY)
      def slide(&block)
        slide = { elements: [] }
        SlideDSL.new(slide).instance_exec(&block)
        @presentation[:slides] << slide
      end
    RUBY
  end
end
