#!/usr/bin/ruby

# Creates a compact overview of recent changes in an Subversion repository.
#
# Author:: Martin Ankerl (mailto:martin.ankerl@gmail.com)
# Copyright:: Copyright (c) 2006-2009 Martin Ankerl
# License:: New BSD License
#
# Homepage:: https://code.google.com/p/svn-shortlog/

# user configuration BEGIN
user_config = {
  :repository => "http://svn.boost.org/svn/boost",
  :url => "http://svn.boost.org/svn/boost/trunk",
  
  # how to extract a library name from a path. Stops after first regexp matches
  :lib_regexp => [
    /trunk\/libs\/([^\/]*)/,
    /trunk\/boost\/([^\/]*)/,
    /trunk\/tools\/([^\/]*)/
  ],
  
  # replacements for in the content message
  :msg_gsubs => [    
    [ /\#(\d+)/, "<a target=\"_blank\" href=\"https://svn.boost.org/trac/boost/ticket/\\1\">\\0</a>"]
  ],
  
  # start revision
  :start => "{2009-12-01}",
  
  # stop revision
  :stop => "{2009-12-31}",

  # footer
  :copyright => "Copyright &copy; #{Time.now.year} <a href=\"http://martin.ankerl.com/\">Martin Ankerl</a>",
}
# user config END

# HTML header with CSS
head = <<-'EOF'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"> 
<html xmlns="http://www.w3.org/1999/xhtml"> 
<head profile="http://gmpg.org/xfn/11"> 
<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" /> 
<meta name="distribution" content="global" /> 
<meta name="robots" content="follow, all" /> 
<style type="text/css">
<!--
BODY ADDRESS{line-height:1.3;margin:0 0}BODY BLOCKQUOTE{margin-top:.75em;line-height:1.5;margin-bottom:.75em}HTML BODY{margin:1em 8% 1em 2%;line-height:1.2}.LEGALNOTICE{font-size:small;font-variant:small-caps}BODY DIV{margin:0}DL{margin:.8em 0;line-height:1.2}BODY FORM{margin:.6em 0}H1,H2,H3,H4,H5,H6,DIV.EXAMPLE P B,.QUESTION,DIV.TABLE P B,DIV.PROCEDURE P B{color:#900}BODY H1,BODY H2,BODY H3,BODY H4,BODY H5,BODY H6{line-height:1.3;margin-left:0}BODY H1,BODY H2{margin:2em 0 0 -1%}BODY H3,BODY H4{margin:.8em 0 0 -1%}BODY H5{margin:.8em 0 0}BODY H6{margin:.8em 0 0 1%}BODY HR{margin:.6em;border-width:0 0 1px;border-style:solid;border-color:#cecece}BODY IMG.NAVHEADER{margin:0 0 0 -4%}OL{margin:0;line-height:1.2}BODY PRE{margin:1em;line-height:1.0;font-family:monospace}BODY TD,BODY TH{line-height:1.2}UL,BODY DIR,BODY MENU{margin:0;line-height:1.2}HTML{margin:0;padding:0}BODY P B.APPLICATION{color:#000}.FILENAME{color:#007a00}.GUIMENU,.GUIMENUITEM,.GUISUBMENU,.GUILABEL,.INTERFACE,.SHORTCUT,.SHORTCUT .KEYCAP{font-weight:bold}.GUIBUTTON{padding:2px;background:#CFCFCF}.ACCEL{text-decoration:underline;background:#F0F0F0}.SCREEN{padding:1ex}.PROGRAMLISTING{padding:1ex;border:1px solid #ccc;background:#eee}@media screen{a[href]:hover{background:#ffa}BLOCKQUOTE.NOTE{color:#222;background:#eee;border:1px solid #ccc;padding:0.4em 0.4em;width:85%}BLOCKQUOTE.TIP{color:#004F00;background:#d8ecd6;border:1px solid green;padding:0.2em 2em;width:85%}BLOCKQUOTE.IMPORTANT{font-style:italic;border:1px solid #a00;border-left:12px solid #c00;padding:0.1em 1em}BLOCKQUOTE.WARNING{color:#9F1313;background:#f8e8e8;border:1px solid #e59595;padding:0.2em 2em;width:85%}.EXAMPLE{background:#fefde6;border:1px solid #f1bb16;margin:1em 0;padding:0.2em 2em;width:90%}A{text-decoration:none}

li {
 white-space:nowrap;
 border-top:1px dotted grey;
 margin:0px;
 padding:5px;
 overflow: hidden;
 text-overflow: ellipsis;
 font-family:Arial;
 cursor:pointer;
}
li:hover {
 background-color:#f0f0f0;
}
.date {
float:right;
}
.lib {
 background-color:#ffcccc;
 padding:1px 2px 1px 2px;
 font-size:small;
 font-family:Arial;
 margin:0px;
 -moz-border-radius: 3px; -webkit-border-radius: 3px;
}
pre, textarea {
 margin:0;
 display:none;
 white-space: pre-wrap;       /* css-3 */
 white-space: -moz-pre-wrap;  /* Mozilla, since 1999 */
 white-space: -pre-wrap;      /* Opera 4-6 */
 white-space: -o-pre-wrap;    /* Opera 7 */
 word-wrap: break-word;       /* Internet Explorer 5.5+ */
}
.files {
 font-family:Arial;
 color:green;
 font-size:small;
}
.cloud {
 font-family:Arial;
 text-align: justify;
 margin: 1em 3em 1em 5em;
}
.tag {
 padding:0 0.5em 0 0.5em;
}
.tag:hover, .file:hover {
 background-color:#000;
 color:#fff;
 -moz-border-radius: 3px; -webkit-border-radius: 3px;
}
.rev {
font-size:small;
}

-->
</style>
<script type="text/javascript">
<!--
    function toggle_visibility(id) {
       var e = document.getElementById(id);
       if(e.style.display == 'block')
          e.style.display = 'none';
       else
          e.style.display = 'block';
    }
//-->
</script>
</head>
<body>
EOF


# here be dragons, modify only if you think you know what you are doing :-)
require 'rexml/document'
require 'date'
require 'iconv'
require 'set'

# extend Date to get local time (hack for Ruby 1.8)
class Date
  def to_gm_time
    to_time(new_offset, :gm)
  end

  def to_local_time
    to_time(new_offset(DateTime.now.offset-offset), :local)
  end

  private
  def to_time(dest, method)
    #Convert a fraction of a day to a number of microseconds
    usec = (dest.sec_fraction * 60 * 60 * 24 * (10**6)).to_i
    Time.send(method, dest.year, dest.month, dest.day, dest.hour, dest.min, dest.sec, usec)
  end
end


class SvnShortlog
  include REXML
  
  def initialize(user_config, head)
    @start_time = Time.now
    @user_config = user_config
    @head = head
  end
  
  class Entry
    attr_accessor :author, :time, :paths, :msg, :rev
  end

  # h, s, v are between [0, 1[
  def hsv_to_rgb(h, s, v)
    h_i = (h*6).to_i
    f = h*6 - h_i
    p = v * (1 - s)
    q = v * (1 - f*s)
    t = v * (1 - (1 - f) * s)
    r, g, b = v, t, p if h_i==0
    r, g, b = q, v, p if h_i==1
    r, g, b = p, v, t if h_i==2
    r, g, b = p, q, v if h_i==3
    r, g, b = t, p, v if h_i==4
    r, g, b = v, p, q if h_i==5
    r = (r*256).to_i
    g = (g*256).to_i
    b = (b*256).to_i
    return sprintf("%02x%02x%02x", r, g, b)
  end

  def htmlize(str, gsubs)
    str = str.gsub("<", "&lt;")
    str.gsub!(">", "&gt;")
    gsubs.each do |regexp, replacement|
      str.gsub!(regexp, replacement)
    end
    str
  end

  # creates array of Entry data blob from SVN XML.
  def parse_xml(doc)
    data = []
    doc.elements.each('log/logentry') do |le|
      e = Entry.new
      e.author = le.elements["author"].text
      e.time = DateTime.parse(le.elements["date"].text).to_local_time
      e.paths = []
      le.elements.each('paths/path') do |pa|
        e.paths.push [pa.attributes["action"], pa.text]
      end	
      e.paths.sort! do |a, b|
        a[1] <=> b[1]
      end
      e.msg = le.elements["msg"].text
      e.msg = htmlize(e.msg, @user_config[:msg_gsubs]) if e.msg
      e.rev = le.attributes["revision"]
      data.push e
    end
    data
  end

  # reformat data blob
  def restructure(d)
    r = Hash.new { |h,k| h[k] = [] }
    d.each do |e|
      r[e.author].push e
    end
    r = r.to_a.sort
  end
  
  def path_to_lib(path)        
    r = @user_config[:lib_regexp].find do |r|
      path.match(r)
    end

    if r
      m = path.match(r)
      m[1]
    else
      nil
    end    
  end
  

  # create tag cloud using LIB_REGEX based on number of time used
  def tag_cloud(entries)
    # collect counts for each library
    h = Hash.new(0)
    entries.each do |e|
      e.paths.each do |kind, path|        
        lib = path_to_lib(path)
        h[lib] += 1 if lib
      end
    end

    min_size = 11
    max_size = 30
    
    max = h.values.max
    h = h.to_a.sort.map do |lib, count|
      # s = min_size + count * (max_size - min_size) / max # linear
      s = (min_size + Math.sqrt(count * max) * (max_size - min_size) / max).to_i # quadratic
      "<span class=\"tag\" style=\"font-size:#{s}px;\" title=\"#{count} changes\">#{lib}</span>"
    end
    "<div class=\"cloud\">#{h.join(" ")}</div>"
  end

  # run everything
  def run

    # get data
    cmd = "svn log #{@user_config[:url]} -r #{@user_config[:start]}:#{@user_config[:stop]} -v --xml"
    puts "running '#{cmd}'"
    f = `#{cmd}`
    data = parse_xml(Document.new(f))
    data = restructure(data)

    # automatically generates colors that are as different as possible.
    colors = Hash.new do |h, k|  
      @val = 0 unless @val
      @val += 0.6180339887; # golden ratio
      @val -= 1 if @val >= 1 
      h[k] = "##{hsv_to_rgb(@val, 0.4, 0.95)}"
      h[k]
    end

    output_filename = "changes_#{@user_config[:start]}_to_#{@user_config[:stop]}.html"
    puts "creating '#{output_filename}'"
    
    #out = STDOUT
    File.open(output_filename, "w") do |out|
      out.puts @head
      
      # unique id for visibility
      id = 0

      out.puts "<h1>Changes from #{@user_config[:start]} to #{@user_config[:stop]}</h1>"

      # quick link to all authors
      authors = data.map { |a,e| "<a href=\"##{a}\">#{a} (#{e.size})</a>" }
      out.puts authors.join(", ")

      # process all data
      data.each do |author, entries|
        # start author
        out.puts "<a name=\"#{author}\"></a><h2>#{author} (#{entries.size})</h2>"
        out.puts tag_cloud(entries)
        out.puts "<ol>"

        # for each commit
        entries.each do |e|
          next unless e.msg

          # start line
          out.puts "<li onclick=\"toggle_visibility('d#{id}');\"><a name=\"#{e.rev}\"></a>"

          # date to the right
          out.puts "<span class=\"date\" title=\"#{e.time.strftime("%H:%M")}\"><small>#{e.rev}</small> #{e.time.strftime('%b %d')}</span>"

          # show colorful used Libs
          libs = Hash.new {|h,k| h[k] = 0 }
          e.paths.each do |kind, path|
            l = path_to_lib(path)
            libs[l] += 1 if l
          end
          libs.to_a.sort.each do |l|
            out.printf "<span class=\"lib\" style=\"background-color:#{colors[l[0]]};\">#{l[0]} <small>#{l[1]}</small></span> "
          end

          # message
          files = e.paths.map do |kind, path|
            "#{kind}&nbsp;#{path}"
          end
          title = "#{e.rev} by #{e.author} on #{e.time.strftime("%b %d %H:%M")}".gsub(" ", "&nbsp;")
          title = "#{title} #{files.join(" ")}"      
          out.puts "<span title=\"#{title}\" class=\"msg\">#{e.msg.split.join(" ")}</span>"

          # files
          files = e.paths.map do |kind, path|
            "<span class=\"file\" title=\"#{kind}&nbsp;#{path}\">#{File.basename(path)}</span>"
          end
          out.puts "<span class=\"files\">#{files.join(", ")}</span>"

          # initially hidden message details
          out.puts "<pre id=\"d#{id}\">"
          out.puts "#{e.rev} by #{e.author} on #{e.time.strftime("%b %d %H:%M")}"
          out.print "<hr />#{e.msg.strip}<hr />"
          e.paths.each do |kind, path|
            out.puts "#{kind} <a target=\"_blank\" href=\"#{@user_config[:repository]}#{path}\">#{path}</a>"
          end      
          out.puts "</pre>"
          out.puts "</li>"
          
          # next ID
          id += 1
        end
        out.puts "</ol>"
      end
      out.puts "<p><hr><center class=\"LEGALNOTICE\">"
      out.puts @user_config[:copyright]
      out.puts "<br />Created in #{Time.now - @start_time} seconds"
      out.puts "</center></body></html>"  
    end
    puts "done!"
    puts 
  end
end

shortlog = SvnShortlog.new(user_config, head)
shortlog.run

