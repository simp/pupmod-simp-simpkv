class libkv::test(
$url = "mock://",
$softfail = true,
) {
	$supports = libkv::supports({'url' => $url, "softfail" => $softfail})
	notify { "supports = ${supports}": }
	$provider = libkv::provider({'url' => $url, "softfail" => $softfail})
	notify { "provider = ${provider}": }
	$loopvar = {
		"/meats/pork"    => "test1",
		"/meats/chicken" => "test4",
		"/meats/turkey"  => "test5",
		"/meats/beef"    => "test2",
		"/fruits/apple"  => "test3",
		"/fruits/banana" => "test4",
	}.each |$key, $value| {
          libkv::put({ 'url' => $url, 'key' => $key, 'value'    => $value, "softfail" => $softfail})
	  $get = libkv::get({'url' => $url, 'key' => $key, "softfail" =>  $softfail})
          notify { "${key} get = ${get}": }
	  $atomic_get = libkv::atomic_get({'url' => $url, 'key' => $key, "softfail" => $softfail})
          notify { "${key} atomic_get = ${atomic_get}": } 
	  libkv::atomic_put({'url'               => $url, 'key' => $key, 'value'    => 'testzor', 'previous' => $atomic_get, "softfail" => $softfail})
	  $atomic_put = libkv::atomic_get({'url' => $url, 'key' => $key, "softfail" =>  $softfail})
          notify { "${key} atomic_put = ${atomic_put}": }
  	  $info = libkv::info({'url' => $url, "softfail" =>  $softfail})
	  notify { "${key} info = ${info}": } 
	}
	$list = libkv::list({ 'url' => $url, 'key' => '/meats', "softfail" => $softfail})
	notify { "first list = ${list}": }
        libkv::delete({'url'  => $url, 'key' => '/meats/pork', "softfail" => $softfail})
	$listm = libkv::list({'url' => $url, 'key' => '/meats', "softfail"      => $softfail })
	notify { "second list = ${listm}": }
	libkv::put({ 'url' => $url, 'key' => "/hosts/${trusted[certname]}/ipaddress", 'value' => $::ipaddress, "softfail" =>  $softfail})
}
