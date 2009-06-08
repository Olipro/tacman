module AuthorAvpairsHelper
    def author_avpair_description(author_avpair, include_mod=false)
        entries = author_avpair.author_avpair_entries
        return("<ul style=\"list-style-type: none;\"><li>author-avpair-list <i>#{author_avpair.name}</i> 10</li><li><i> &nbsp&nbsp empty set</i></li></ul>") if (entries.length == 0)

        str = "<ul style=\"list-style-type: none;\">\n"
        entries.each do |e|
            net_av = e.network_av
            sc_av = e.shell_command_av
            str << "<li>author-avpair-list <i>#{author_avpair.name}</i> #{e.sequence}</li>\n"
            str << "<li> &nbsp&nbsp match access-list <i>#{link_to e.acl.name, acls_configuration_url(@configuration) }</i></li>\n"if (e.acl_id)
            str << "<li> &nbsp&nbsp set service=#{e.service}</li>\n"
            e.avpairs.each {|avp| str << "<li> &nbsp&nbsp set #{avp.avpair}</li>\n"}
            if (net_av)
                vals = ""
                net_av.dynamic_avpair_values.each {|v| vals << "<i>#{link_to v.network_object_group.name, network_object_groups_configuration_url(@configuration) }</i> "}
                str << "<li> &nbsp&nbsp define network-av \"#{net_av.attr}\" delimiter \"#{net_av.delimiter}\" object-groups #{vals}</li>\n"
            end

            if (sc_av)
                vals = ""
                sc_av.dynamic_avpair_values.each {|v| vals << "<i>#{link_to v.shell_command_object_group.name, shell_command_object_groups_configuration_url(@configuration) }</i> "}
                str << "<li> &nbsp&nbsp define shell-command-av \"#{sc_av.attr}\" delimiter \"#{sc_av.delimiter}\" object-groups #{vals}</li>\n"
            end

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
