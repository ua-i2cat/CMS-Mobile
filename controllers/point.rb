class CMS
  module Controllers
    class Point
      def self.get params
        id = params['id']
        point = Models::Point.get(id)
        if point.nil?
          nil
        else
          point
        end
      end

      def self.create params
        name = params['name']
        description = params['description']
        coord_x, coord_y = Utils::Coordinates.parse(params['coords'])

        point = Models::Point.create(
          :name => name,
          :description => description,
          :coord_x => coord_x,
          :coord_y => coord_y,
          :created_at => Time.now,
          :updated_at => Time.now,
          :weight => Models::Point.count + 1
        )

        if point.saved?
          true
        else
          false
        end
      end

      def self.destroy params
        id = params['id']
        point = Models::Point.get(id)
        if point.nil?
          false
        elsif point.destroy
          true
        else
          false
        end
      end

      def self.publish params
        id = params['id']
        point = Models::Point.get(id)
        if point.nil?
          return false
        end

        point.published = true

        if point.save
          true
        else
          false
        end
      end

      def self.unpublish params
        id = params['id']
        point = Models::Point.get(id)
        if point.nil?
          return false
        end

        point.published = false

        if point.save
          true
        else
          false
        end
      end

      def self.edit params
        id = params['id']
        name = params['name']
        description = params['description']
        coord_x, coord_y = Utils::Coordinates.parse(params['coords'])
        published = (params['published'] == 'on')
        multimedia_main = params['multimedia-main']

        point = Models::Point.get(id)
        if point.nil?
          return false
        end

        success = point.update(
          :name => name,
          :description => description,
          :coord_x => coord_x,
          :coord_y => coord_y,
          :updated_at => Time.now,
          :published => published
        )
        if success
          return true
        else
          return false
        end
      end

      def self.up params
        id = params['id']

        point = Models::Point.get(id)

        return false if point.nil?
        return false if point.weight == 1

        next_point = Models::Point.first(:weight => (point.weight - 1))

        next_point.weight = point.weight
        point.weight -= 1

        return point.save && next_point.save
      end

      def self.down params
        id = params['id']

        point = Models::Point.get(id)
        return false if point.nil?
        return false if point.weight == Models::Point.count

        prev_point = Models::Point.first(:weight => (point.weight + 1))

        prev_point.weight = point.weight
        point.weight += 1

        return point.save && prev_point.save
      end

      def self.edit_multimedia params
        point = Models::Point.get(params['point'])

        return false if point.nil?

        case params['action']
        when 'link'
          multimedia = Models::Multimedia.get(params['multimedia'])
          return false if multimedia.nil?
          point.multimedias << multimedia
        when 'unlink'
          multimedia = point.multimedias.get(params['multimedia'])
          return false if multimedia.nil?
          return false unless point.multimedias.delete(multimedia)
        else
          return false
        end

        unless point.save #multimedias.save
          raise ArgumentError, "hola"
          return false
        end
        return point.multimedias.save
      end
    end
  end
end
