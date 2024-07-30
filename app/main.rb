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
  end
end
