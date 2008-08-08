module AuthorAvpairsHelper
    def author_avpair_description(author_avpair, include_mod=false)
        entries = author_avpair.author_avpair_entries
        return("<ul style=\"list-style-type: none;\"><li>author-avpair-list <i>#{author_avpair.name}</i> 10</li><li><i> &nbsp&nbsp empty set</i></li></ul>") if (entries.length == 0)

        str = "<ul style=\"list-style-type: none;\">\n"
        entries.each do |e|
            str << "<li>author-avpair-list <i>#{author_avpair.name}</i> #{e.sequence}</li>\n"
            str << "<li> &nbsp&nbsp match access-list <i>#{e.acl.name}</i></li>\n"if (e.acl_id)
            str << "<li> &nbsp&nbsp set service=#{e.service}</li>\n"
            e.avpairs.each {|avp| str << "<li> &nbsp&nbsp set #{avp.avpair}</li>\n"}
            if (include_mod)
                str << "<li> &nbsp&nbsp <i>"
                str <<  link_to("remove &nbsp &nbsp", author_avpair_entry_url(e), :method => :delete)
                str <<  link_to("edit", edit_author_avpair_entry_url(e))
                str << "</i></li>"
            end
            str << "<li>&nbsp</li>\n"
        end
        str << "</ul>\n"
        return(str)
    end
end
