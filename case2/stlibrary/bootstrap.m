function bootstrap(downloadData)
%BOOTSTRAP Install algorithm dependencies and optionally download CDnet 2014.
if nargin<1, downloadData=false; end
st_setup();
setup_third_party;
if downloadData, download_cdnet2014; end
end
