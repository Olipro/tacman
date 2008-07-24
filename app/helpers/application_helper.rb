# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
    def password_lifespan_options(additional=nil)
        default1 = @local_manager.default_login_password_lifespan
        default2 = @local_manager.default_enable_password_lifespan
        vals = [15,30,60,90,180,365]
        vals.push(default1) if ( default1 != 0 && !vals.include?(default1) )
        vals.push(default2) if ( default2 != 0 && !vals.include?(default2) )
        vals.push(additional) if (additional && additional != 0)
        vals.sort!
        vals = vals.collect {|x| ["#{x} days", x] }
        vals.push(['unlimited', 0])
        return(vals)
    end

    def password_lifespan_xlate(days)
        if (days == 0)
            return('<b style="color: #7B2024">unlimited</b>')
        else
            return("#{days} days")
        end
    end
end
