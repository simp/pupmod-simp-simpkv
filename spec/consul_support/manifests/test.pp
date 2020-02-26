class simpkv::test(
$url = 'mock://'
) {
  $supports = simpkv::supports({'url' => $url})
  notify { "supports = ${supports}": }
  $provider = simpkv::provider({'url' => $url})
  notify { "provider = ${provider}": }
  $loopvar = {
    '/meats/pork'    => 'test1',
    '/meats/chicken' => 'test4',
    '/meats/turkey'  => 'test5',
    '/meats/beef'    => 'test2',
    '/fruits/apple'  => 'test3',
    '/fruits/banana' => 'test4',
  }.each |$key, $value| {
          simpkv::put({ 'url' => $url, 'key' => $key, 'value' => $value});
    $get = simpkv::get({'url' => $url, 'key'       => $key});
          notify { "${key} get = ${get}": }
    $atomic_get = simpkv::atomic_get({'url' => $url, 'key' => $key});
          notify { "${key} atomic_get = ${atomic_get}": }
    simpkv::atomic_put({'url'            => $url, 'key' => $key, 'value' => 'testzor', 'previous' => $atomic_get});
    $atomic_put = simpkv::atomic_get({'url' =>  $url, 'key'       => $key});
          notify { "${key} atomic_put = ${atomic_put}": }
      $info = simpkv::info({'url' => $url})
    notify { "${key} info = ${info}": }
  }
  $list = simpkv::list({ 'url' => $url, 'key' => '/meats' })
  notify { "first list = ${list}": }
        simpkv::delete({'url'  => $url, 'key' => '/meats/pork'})
  $listm = simpkv::list({'url' => $url, 'key'       => '/meats' })
  notify { "second list = ${listm}": }
  simpkv::put({ 'url' => $url, 'key' => "/hosts/${trusted[certname]}/ipaddress", 'value' => $::ipaddress})
}
