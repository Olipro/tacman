class SystemRevision < ActiveRecord::Base
    belongs_to :manager

    validates_presence_of :revision
    validates_presence_of :queue
    validates_format_of :queue, :with => /(inbox|outbox)/, :message => "must be either 'inbox' or 'outbox'."
end
