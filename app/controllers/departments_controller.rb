class DepartmentsController < ApplicationController
    before_filter :define_session_user
    before_filter :force_pw_change
    before_filter :authorize_user_admin


    def create
        @department = Department.new(params[:department])

        respond_to do |format|
            @nav = 'index_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to departments_url }
                format.xml  { render :xml => @department.errors, :status => :not_acceptable }
            elsif @department.save
                @local_manager.log(:username => @session_user.username, :department_id => @department.id, :message => "Created Department '#{@department.name}'.")
                format.html { redirect_to departments_url }
                format.xml  { render :xml => @department, :status => :created, :location => @department }
            else
                format.html { render :action => "new" }
                format.xml  { render :xml => @department.errors, :status => :unprocessable_entity }
            end
        end
    end

    def destroy
        @department = Department.find(params[:id])

        respond_to do |format|
            @nav = 'show_nav'
            if (@local_manager.slave?)
                flash[:warning] = "This action is prohibited on slave systems."
                format.html { redirect_to departments_url }
                format.xml  { render :xml => @department.errors, :status => :not_acceptable }
            else
                @department.destroy
                @local_manager.log(:username => @session_user.username, :message => "Deleted Department '#{@department.name}'.")
                format.html { redirect_to(departments_url) }
                format.xml  { head :ok }
            end
        end
    end

    def edit
        @department = Department.find(params[:id])
        @nav = 'index_nav'
    end

    def index
        @departments = Department.find(:all, :order => :name)

        respond_to do |format|
            @nav = 'index_nav'
            format.html # index.html.erb
            format.xml  { render :xml => @departments }
        end
    end

    def new
        @department = Department.new()

        respond_to do |format|
            @nav = 'index_nav'
            format.html # new.html.erb
            format.xml  { render :xml => @department }
        end
    end

    def show
        @department = Department.find(params[:id])
        @log_count = SystemLog.count_by_sql("SELECT COUNT(*) FROM system_logs WHERE department_id=#{@department.id}")
        if ( params.has_key?(:page) )
            page = params[:page]
        elsif (@log_count > 0)
            page = @log_count / @local_manager.pagination_per_page
            page = page + 1 if (@log_count % @local_manager.pagination_per_page > 0)
        end
        @logs = SystemLog.paginate(:page => page, :per_page => @local_manager.pagination_per_page,
                                   :conditions => "department_id=#{@department.id}", :order => :created_at)
        respond_to do |format|
            @nav = 'index_nav'
            format.html
        end
    end

    def update
        @department = Department.find(params[:id])

        respond_to do |format|
            @nav = 'index_nav'
            if (@local_manager.slave?)
                @department.errors.add_to_base("This action is prohibited on slave systems.")
                format.html { render :action => "edit" }
                format.xml  { render :xml => @department.errors, :status => :not_acceptable }
            elsif @department.update_attributes(params[:department])
                @local_manager.log(:username => @session_user.username, :department_id => @department.id, :message => "Updated Department '#{@department.name}'.")
                format.html { redirect_to departments_url }
                format.xml  { head :ok }
            else
                format.html { render :action => "edit" }
                format.xml  { render :xml => @department.errors, :status => :unprocessable_entity }
            end
        end
    end


end
