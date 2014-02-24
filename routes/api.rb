require 'builder'

module CMS
  module Routes
    class API < Base
      before do
        content_type 'text/xml'
      end

      get '/api' do
        redirect '/api/info'
      end

      get '/api/info' do
        builder do |xml|
          xml.instruct!
          xml.info :time => DateTime.now do
            xml.status "UP"
            xml.points "/api/points"
            xml.extras "/api/extras"
          end
        end
      end

      get '/api/points' do
        builder do |xml|
          xml.instruct!
          xml.points do
            CMS::Models::Point.published.not_deleted.all(
              :published => true, :order => [:weight.desc]
            ).each_with_index do |p, i|
              xml.point({
                :order => i + 1,
                :id => p.id,
                :name => p.name,
                :url => link_to("/api/point/#{p.id}")
              })
            end
          end
        end
      end

      get '/api/point/:id' do |id|
        p = CMS::Models::Point.get(id)
        builder do |xml|
          xml.instruct!
          xml.point :name => p.name, :id => p.id do
            xml.description p.description
            xml.multimedias do
              p.multimedias_sorted.each_with_index do |m, i|
                xml.multimedia :order => i + 1, :id => m.id, :name => m.name do
                  xml.description m.description
                  xml.tip m.tip
                  xml.url link_to(m.static_link)
                end
              end
            end
            xml.extras do
              p.extras_sorted.each_with_index do |e, i|
                xml.extra({
                  :order => i + 1,
                  :id => e.id,
                  :name => e.name,
                  :url => link_to("/api/extra/#{e.id}")
                })
              end
            end
          end
        end
      end

      get '/api/extra/:id' do |id|
        e = CMS::Models::Extra.get(id)
        builder do |xml|
          xml.instruct!
          xml.extra :name => e.name, :id => e.id do
            xml.description e.description
            xml.multimedias do
              e.multimedias_sorted.each_with_index do |m, i|
                xml.multimedia :order => i + 1, :id => m.id, :name => m.name do
                  xml.description m.description
                  xml.tip m.tip
                  xml.url link_to(m.static_link)
                end
              end
            end
          end
        end
      end

      get '/api/all' do
        builder do |xml|
          xml.instruct!
          xml.points do
            CMS::Models::Point.all_sorted.published.not_deleted.each_with_index do |point, i|
              xml.point :order => i + 1, :id => point.id do
                xml.name point.name
                xml.description point.description
                xml.tip point.tip
                xml.multimedias do
                  point.multimedias_sorted.published.each_with_index do |multimedia, i|
                    xml.multimedia :order => i + 1, :id => multimedia.id do
                      xml.name multimedia.name
                      xml.description multimedia.description
                      xml.tip multimedia.tip
                      xml.url link_to(multimedia.static_link)
                    end
                  end
                end

                xml.extras do
                  point.extras_sorted.published.not_deleted.each_with_index do |extra, i|
                    xml.extra :order => i + 1, :id => extra.id do
                      xml.name extra.name
                      xml.description extra.description
                      xml.tip extra.tip
                      xml.multimedias do
                        extra.multimedia_sorted.each_with_index do |multimedia, i|
                          xml.multimedia :order => i + 1, :id => multimedia.id do
                            xml.name multimedia.name
                            xml.description multimedia.description
                            xml.tip multimedia.tip
                            xml.url link_to(multimedia.static_link)
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
