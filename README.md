# 新一代 Qiniu SDK for Ruby

[![Code Climate](https://codeclimate.com/github/bachue/ngruby-sdk.svg)](https://codeclimate.com/github/bachue/ngruby-sdk) [![Build Status](https://api.travis-ci.com/bachue/ruby-ng-sdk.svg?branch=master)](https://travis-ci.org/bachue/ngruby-sdk) [![Coverage Status](https://coveralls.io/repos/bachue/ngruby-sdk/badge.svg?branch=master)](https://coveralls.io/r/bachue/ngruby-sdk?branch=master)

## 关于

此 Ruby SDK 基于 [七牛云存储官方 API](http://developer.qiniu.com/) 构建。使用此 SDK 构建您的网络应用程序，能让您以非常便捷地方式将数据安全地存储到七牛云存储上。无论您的网络应用是一个网站程序，还是包括从云端（服务端程序）到终端（手持设备应用）的架构的服务或应用，通过七牛云存储及其 SDK，都能让您应用程序的终端用户高速上传和下载，同时也让您的服务端更加轻盈。

支持的 Ruby 版本：

* Ruby 2.3.x
* Ruby 2.4.x
* Ruby 2.5.x
* Ruby 2.6.x
* JRuby 9.1.x
* JRuby 9.2.x

您可能使用过先前七牛发布的另一个 [Ruby SDK](https://github.com/qiniu/ruby-sdk.git)，该 Ruby SDK 已经停止维护。请在条件允许的情况下，尽快改用本 SDK。

本 SDK 相比于旧的 [Ruby SDK](https://github.com/qiniu/ruby-sdk.git)，重新设计了所有 API，拥有更强大的功能，并对 Carrierwave, ActiveStorage 等开源工具进行了集成。

本 SDK 与旧的 [Ruby SDK](https://github.com/qiniu/ruby-sdk.git) 在 API 上不兼容，但可以共存。

## 安装

在您 Ruby 应用程序的 `Gemfile` 文件中，添加如下一行代码：

    gem 'qiniu-ng', '~> 0.9'

然后，在应用程序所在的目录下，可以运行 `bundle` 安装依赖包：

    $ bundle

或者，可以使用 Ruby 的包管理器 `gem` 进行安装：

    $ gem install qiniu-ng

## 贡献代码

1. Fork
2. 创建您的特性分支 (`git checkout -b my-new-feature`)
3. 提交您的改动 (`git commit -am 'Added some feature'`)
4. 将您的修改记录提交到远程 `git` 仓库 (`git push origin my-new-feature`)
5. 然后到 github 网站的该 `git` 远程仓库的 `my-new-feature` 分支下发起 Pull Request

## 许可证

Copyright (c) 2012-2014 qiniu.com

基于 MIT 协议发布:

* [www.opensource.org/licenses/MIT](http://www.opensource.org/licenses/MIT)

## 入门指南

### 配置

在应用初始化期间，您需要创建七牛客户端，并考虑将其设置为全局变量以便于在之后持续使用该客户端。

如果您使用的是 Rails，可以创建一个初始化脚本来初始化七牛客户端：

```
config/initializers/qiniu.rb
```

初始化客户端的代码如下：

```ruby
$qiniu = QiniuNg.new_client(access_key: '<Qiniu AccessKey>', secret_key: '<Qiniu SecretKey>')
```

该客户端在整个应用中仅需初始化一次即可。

### 对象存储

#### 上传流程

文件上传分为客户端上传（主要是指网页端和移动端等面向终端用户的场景）和服务端上传两种场景，具体可以参考文档[业务流程](https://developer.qiniu.com/kodo/manual/1205/programming-model)。

服务端SDK在上传方面主要提供两种功能，一种是生成客户端上传所需要的上传凭证，另外一种是直接上传文件到云端。

#### 客户端上传凭证

客户端（移动端或者Web端）上传文件的时候，需要从客户自己的业务服务器获取上传凭证，而这些上传凭证是通过服务端的SDK来生成的，然后通过客户自己的业务 API 分发给客户端使用。
根据上传的业务需求不同，七牛云 Ruby SDK 支持丰富的上传凭证生成方式。

##### 简单上传的凭证

最简单的上传凭证只需要 `Bucket Name` 就可以。

```ruby
$qiniu.bucket('<Bucket Name>').upload_token.to_s
```

##### 覆盖上传的凭证

覆盖上传除了需要简单上传所需要的信息之外，还需要想进行覆盖的文件名称，这个文件名称同时可是客户端上传代码中指定的文件名，两者必须一致。

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').upload_token.to_s
```

##### 自定义上传回复的凭证

默认情况下，文件上传到七牛之后，在没有设置 `returnBody` 或者 回调 相关的参数情况下，七牛返回给上传端的回复格式为 `hash` 和 `key`，例如：

```json
{"hash":"Ftgm-CkWePC9fzMBTRNmPMhGBcSV","key":"qiniu.jpg"}
```

有时候我们希望能自定义这个返回的JSON格式的内容，可以通过设置 `returnBody` 参数来实现，在 `returnBody` 中，我们可以使用支持的[魔法变量](https://developer.qiniu.com/kodo/manual/1235/vars#magicvar)和[自定义变量](https://developer.qiniu.com/kodo/manual/1235/vars#xvar)。

```ruby
$qiniu.bucket('<Bucket Name>').upload_token { |policy|
  policy.set_return body: '{"key":"$(key)","hash":"$(etag)","bucket":"$(bucket)","fsize":$(fsize)}'
}.to_s
```

则文件上传到七牛之后，收到的回复内容如下：

```json
{"key":"qiniu.jpg","hash":"Ftgm-CkWePC9fzMBTRNmPMhGBcSV","bucket":"if-bc","fsize":39335}
```

##### 带回调业务服务器的凭证

上面生成的自定义上传回复的上传凭证适用于上传端（无论是客户端还是服务端）和七牛服务器之间进行直接交互的情况下。
在客户端上传的场景之下，有时候客户端需要在文件上传到七牛之后，从业务服务器获取相关的信息，这个时候就要用到七牛的上传回调及相关回调参数的设置。

```ruby
$qiniu.bucket('<Bucket Name>').upload_token { |policy|
  policy.set_callback 'http://api.example.com/qiniu/upload/callback',
                      body: '{"key":"$(key)","hash":"$(etag)","bucket":"$(bucket)","fsize":$(fsize)}',
                      body_type: 'application/json'
}.to_s
```

在使用了上传回调的情况下，客户端收到的回复就是业务服务器响应七牛的 JSON 格式内容。

通常情况下，我们建议使用 `application/json` 格式来设置 `callbackBody`，保持数据格式的统一性。
实际情况下，`callbackBody` 也支持 `application/x-www-form-urlencoded` 格式来组织内容，这个主要看业务服务器在接收到 `callbackBody` 的内容时如何解析。例如：

```ruby
$qiniu.bucket('<Bucket Name>').upload_token { |policy|
  policy.set_callback 'http://api.example.com/qiniu/upload/callback',
                      body: 'key=$(key)&hash=$(etag)&bucket=$(bucket)&fsize=$(fsize)'
}.to_s
```

##### 综合上传凭证

上面的生成上传凭证的方法，都是通过设置[上传策略](https://developer.qiniu.com/kodo/manual/1206/put-policy)相关的参数来支持的，这些参数可以通过不同的组合方式来满足不同的业务需求，可以灵活地组织你所需要的上传凭证。点击[这里](https://bachue.github.io/ruby-ng-sdk/QiniuNg/Storage/Model/UploadPolicy.html)阅读详细的 API 文档。

#### 服务器直传

服务端直传是指客户利用七牛服务端 SDK 从服务端直接上传文件到七牛云，交互的双方一般都在机房里面，所以服务端可以自己生成上传凭证，然后利用 SDK 中的上传 API 进行上传，最后从七牛云获取上传的结果，这个过程中由于双方都是业务服务器，所以很少利用到上传回调的功能，而是直接自定义 `returnBody` 来获取自定义的回复内容。

##### 文件上传

```ruby
bucket = $qiniu.bucket('<Bucket Name>')
bucket.upload filepath: '/home/qiniu/test.png',
              key: '<Key in Bucket>',           # 可选参数，如果不指定，将以文件内容的 hash 值作为文件名
              upload_token: bucket.upload_token # 可以不调用 #to_s 方法
```

##### IO 流上传

```ruby
bucket = $qiniu.bucket('<Bucket Name>')
bucket.upload stream: StringIO.new('hello qiniu cloud'), # 这里只需要 IO 流实现 #read 方法即可
              key: '<Key in Bucket>', # 可选参数，如果不指定，将以文件内容的 hash 值作为文件名
              upload_token: bucket.upload_token # 可以不调用 #to_s 方法
```

##### 解析自定义回复内容

对于服务器端上传的情况，不建议您修改 `returnBody` 中的默认的 `key` 和 `hash` 两个参数，否则会导致 Ruby SDK 无法对上传结果进行校验。
也不要将 `returnBody` 的类型改为 JSON 以外的类型，否则将导致 Ruby SDK 抛出异常。

而对于您向 `returnBody` 增加了更多参数的情况：

```ruby
$qiniu.bucket('<Bucket Name>').upload_token { |policy|
  policy.set_return body: '{"key":"$(key)","hash":"$(etag)","bucket":"$(bucket)","fsize":$(fsize)}'
}.to_s
```

可以通过调用 `bucket#upload` 的返回值的 `#[]` 方法来得到结果。

```ruby
bucket = $qiniu.bucket('<Bucket Name>')
result = bucket.upload filepath: '/home/qiniu/test.png',
                       key: '<Key in Bucket>',           # 可选参数，如果不指定，将以文件内容的 hash 值作为文件名
                       upload_token: bucket.upload_token # 可以不调用 #to_s 方法
p result['bucket']
p result['fsize']
```

##### 业务服务器验证七牛回调

在上传策略里面设置了上传回调相关参数的时候，七牛在文件上传到服务器之后，会主动地向 `callbackUrl` 发送POST请求的回调，回调的内容为 `callbackBody` 模版所定义的内容，
如果这个模版里面引用了[魔法变量](https://developer.qiniu.com/kodo/manual/1235/vars#magicvar)或者[自定义变量](https://developer.qiniu.com/kodo/manual/1235/vars#xvar)，那么这些变量会被自动填充对应的值，然后在发送给业务服务器。

业务服务器在收到来自七牛的回调请求的时候，可以根据请求头部的 `Authorization` 字段来进行验证，查看该请求是否是来自七牛的未经篡改的请求。具体可以参考七牛的 `回调鉴权`。

以 Rails Controller 为例：

```ruby
def callback
  unless $qiniu.callback_valid?(request.headers['Authorization'],
                                 request.original_url,
                                 content_type: request.headers['Content-Type'],
                                 body: request.raw_post)
    render status: :unauthorized, json: { error: 'Bad Authorization Token' }
    return
  end
  # Continue
end
```

#### 下载文件

文件下载分为公开空间的文件下载和私有空间的文件下载。

##### 公开空间的下载地址

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').download_url
```

##### 私有空间的下载地址

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').download_url.private
```

##### 下载云存储文件到本地

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').download_url.download_to '/local/path/on/disk'
$qiniu.bucket('<Bucket Name>').entry('<Key>').download_url.private.download_to '/local/path/on/disk'
```

#### 资源管理

##### 获取文件信息

```ruby
stat = $qiniu.bucket('<Bucket Name>').entry('<Key>').stat
p stat.file_size
p stat.etag
p stat.mime_type
p stat.put_at
```

##### 修改文件类型

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').change_mime_type new_mime_type
```

##### 移动或重命名文件

移动操作本身支持移动文件到相同，不同空间中，在移动的同时也可以支持文件重命名。唯一的限制条件是，移动的源空间和目标空间必须在同一个机房。

如果目标文件已存在，可以设置强制覆盖参数 `force` 来覆盖那个文件的内容。

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').rename_to '<New Key>'
$qiniu.bucket('<Bucket Name>').entry('<Key>').move_to '<New Bucket Name>', '<New Key>', force: true
```

##### 复制文件

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').copy_to '<Target Bucket Name>', '<Target Key>'
```

##### 删除文件

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').delete
```

##### 设置或更新文件的生存时间

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').set_lifetime days: '<Lifetime>'
```

##### 获取空间文件列表

```ruby
$qiniu.bucket('<Bucket Name>').files.each do |file|
  p file.key
  p file.hash
  p file.mime_type
  p file.file_size
  p file.put_at
end
```

##### 抓取网络资源到空间

```ruby
remote_src_url = 'http://devtools.qiniu.com/qiniu.png'
$qiniu.bucket('<Bucket Name>').entry('<Key>').fetch_from remote_src_url
```

#### 资源管理批量操作

##### 批量获取文件信息

```ruby
results = $qiniu.bucket('<Bucket Name>').batch do |b|
            b.stat '1.mp4'
            b.stat '2.mp4'
            b.stat '3.mp4'
          end
results.each do |result|
  raise result.error unless result.success?
  p result.hash
  p result.mime_type
  p result.file_size
  p result.put_at
end
```

##### 批量修改文件类型

```ruby
results = $qiniu.bucket('<Bucket Name>').batch do |b|
            b.change_mime_type '1.mp4', 'video/mp4'
            b.change_mime_type '2.mp4', 'video/mp4'
            b.change_mime_type '3.mp4', 'video/mp4'
          end
p results.any? &:failed?
```

##### 批量删除文件

```ruby
results = $qiniu.bucket('<Bucket Name>').batch do |b|
            b.delete '1.mp4'
            b.delete '2.mp4'
            b.delete '3.mp4'
          end
p results.any? &:failed?
```

##### 批量移动或重命名文件

```ruby
results = $qiniu.bucket('<Bucket Name>').batch do |b|
            b.move from: '1.mp4', to: '1_move.mp4', to_bucket: '<Target Bucket Name>'
            b.move from: '2.mp4', to: '2_move.mp4', to_bucket: '<Target Bucket Name>'
            b.move from: '3.mp4', to: '3_move.mp4', to_bucket: '<Target Bucket Name>'
          end
p results.any? &:failed?
```

##### 批量复制文件

```ruby
results = $qiniu.bucket('<Bucket Name>').batch do |b|
            b.copy from: '1.mp4', to: '1_copy.mp4', to_bucket: '<Target Bucket Name>'
            b.copy from: '2.mp4', to: '2_copy.mp4', to_bucket: '<Target Bucket Name>'
            b.copy from: '3.mp4', to: '3_copy.mp4', to_bucket: '<Target Bucket Name>'
          end
p results.any? &:failed?
```

##### 批量混合指令操作

其实 `batch` 接口支持混合指令的处理，不过为了方便解析请求的回复，一般不推荐这样做。

```ruby
results = $qiniu.bucket('<Bucket Name>').batch do |b|
            b.stat '1.mp4'
            b.copy from: '2.mp4', to: '2_copy.mp4', to_bucket: '<Target Bucket Name>'
            b.move from: '3.mp4', to: '3_copy.mp4', to_bucket: '<Target Bucket Name>'
            b.delete '4.mp4'
          end
p results.any? &:failed?
```

#### 更新镜像存储空间中文件内容

对于配置了镜像存储的空间，如果镜像源站更新了文件内容，则默认情况下，七牛不会再主动从客户镜像源站同步新的副本。
这个时候就需要利用这个 `prefetch` 接口来主动地将空间中的文件和更新后的源站副本进行同步。

```ruby
$qiniu.bucket('<Bucket Name>').entry('<Key>').prefetch
```

#### 与第三方插件集成

##### 与 CarrierWave 集成

* 首先，在 Rails 中的 `config/initializers/carrierwave.rb` 配置七牛作为存储后端

```ruby
CarrierWave.configure do |config|
  config.storage = :qiniu_ng
  config.qiniu_access_key = '<Qiniu AccessKey>'
  config.qiniu_secret_key = '<Qiniu SecretKey>'
  config.qiniu_bucket_name = '<Qiniu BucketName>'
end
```

* 生成需要用到的 Uploader 类

```ruby
class AvatarUploader < CarrierWave::Uploader::Base
  storage :qiniu_ng        # 设置后端存储为七牛云
end
```

* 生成使用 Uploader 类的 ActiveRecord 类

```ruby
class User < ActiveRecord::Base
  mount_uploader :avatar, AvatarUploader
end
```

* 通过 ActiveRecord 向七牛云上传 / 下载数据

```ruby
user = User.new
user.avatar = params[:file]                             # 将用户上传的文件赋值给 avatar 字段
user.save!                                              # 保存数据到数据库，并将用户上传的文件上传至七牛云
user.avatar.url                                         # 获取上传文件的下载地址
user.avatar.url(style: 'small')                         # 获取带有样式的下载地址
user.avatar.url(fop: 'imageView/2/h/200')               # 获取带有数据处理的下载地址
user.avatar.url.download_to('/local/file/path/on/disk') # 下载上传的文件到本地
```

### 数据处理
### CDN
### 直播
### 连麦
### 云短信

开发中

### 高级初始化配置
