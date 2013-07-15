description 'Use ace editor'
dependencies 'utils/assets'
export_scripts '*.js'

Application.hook :head do
  %{<script src="http://d1n0x3qji82z53.cloudfront.net/src-min-noconflict/ace.js" type="text/javascript"></script>}
end
