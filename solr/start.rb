root = File.expand_path("..", __FILE__)
jar_path = ENV["SOLR_JAR_PATH"] || "/usr/local/Cellar/solr/3.6.1/libexec/example/start.jar"

Dir.chdir(File.dirname(jar_path)) do
  exec "java -Dsolr.data.dir=#{root}/data -Dsolr.solr.home=#{root} -Djetty.port=8985 -jar #{File.basename(jar_path)}"
end
