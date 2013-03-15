class Numeric
   TO_RAD = Math::PI / 180.0
   TO_DEG = 180.0 / Math::PI
   def to_rad
     self * TO_RAD
   end
   def to_deg
     self * TO_DEG
   end
end

module RDoc
# File lib/rdoc/usage.rb, line 98
  def RDoc.file_no_exit(filename,*args)
    content = IO.readlines(filename).join
    markup = SM::SimpleMarkup.new
    flow_convertor = SM::ToFlow.new
    flow = markup.convert(content, flow_convertor)

    format = "plain"

    unless args.empty?
      flow = extract_sections(flow, args)
    end

    options = RI::Options.instance
    if args = ENV["RI"]
      options.parse(args.split)
    end
    formatter = options.formatter.new(options, "")
    formatter.display_flow(flow)
  end
end
  
