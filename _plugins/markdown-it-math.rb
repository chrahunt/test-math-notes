# Different parser to avoid messing up LaTeX
=begin
class Jekyll::Converters::Markdown::MarkdownItMath
  def initialize(config)
    require 'motion-markdown-it'
  end
end
=end
