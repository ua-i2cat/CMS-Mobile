module CMS
  module Models
    class GroupMultimedia
      include DataMapper::Resource
      include Core::SortFields

      belongs_to :group, 'Group', :key => true
      belongs_to :multimedia, :key => true

      # Override Core::Sortfields methods and hooks
      before :create do |record|
        heaviest_record = GroupMultimedia.first(:group => self.group, :order => [:weight.desc])
        record.weight = if heaviest_record.nil?
                          1
                        else
                          heaviest_record.weight + 1
                        end
      end

      def self.all_sorted
        self.all(:order => [:weight.asc])
      end
    end
  end
end
