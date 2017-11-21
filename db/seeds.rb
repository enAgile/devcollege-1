logger = Rails.logger

def add_genre(category, parent, object, depth)
  genre = Genre.create!(
    category: category,
    parent_id: parent&.id,
    name: object['name'],
    itunes_genre_id: object['id']
  )

  return if depth > 1

  object['subgenres']&.values&.each do |value|
    add_genre(category, genre, value, depth + 1)
  end
end

#
# Import Genres
#
Genre.delete_all

url = 'http://itunes.apple.com/WebObjects/MZStoreServices.woa/ws/genres?cc=jp'
response = Faraday.get(url)
result = JSON.parse(response.body)
result.each_values do |value|
  category = value['name']
  next unless category.in?(%w(映画 ミュージック ミュージックビデオ))
  add_genre(category, nil, value, 1)
end
logger.info "Import #{Genre.count} genres."

#
# Import Meida
#
Medium.delete_all

Genre.all.find_each do |genre|
  type = case genre.category
         when '映画'
           'movies'
         when 'ミュージック'
           'songs'
         end

  url = "https://itunes.apple.com/jp/rss/top#{type}/limit=10/genre=#{genre.itunes_genre_id}/json"
  response = Faraday.get(url)

  (JSON.parse(response.body)['feed']['entry'] || []).each.with_index(1) do |entry, rank|
    medium = Medium.find_or_create_by!(itunes_medium_id: entry['id']['attributes']['im:id']) do |m|
      m.name = entry['im:name']['label']
      m.category = entry['im:contentType']['attributes']['label']
      m.price_amount = entry['im:price']['attributes']['amount']
      m.price_currency = entry['im:price']['attributes']['currency']
      m.copyrights = entry['im:name']['rights']
      m.artist = entry['im:artist']['label']
      m.summary = entry['summary']&.fetch('label', nil)
      m.image_url = entry['im:image'].last['label']
    end

    genre.media_rankings.create!(medium: medium, rank: rank)
  end
  logger.info "Import #{Medium.count} media. [genre: #{genre.name}]"

  sleep(1)
end
