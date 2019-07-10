# 新一代 Qiniu SDK for Ruby

[![Code Climate](https://codeclimate.com/github/bachue/ngruby-sdk.svg)](https://codeclimate.com/github/bachue/ngruby-sdk) [![Build Status](https://api.travis-ci.org/bachue/ngruby-sdk.svg?branch=master)](https://travis-ci.org/bachue/ngruby-sdk) [![Coverage Status](https://coveralls.io/repos/bachue/ngruby-sdk/badge.svg?branch=master)](https://coveralls.io/r/bachue/ngruby-sdk?branch=master)

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

本 SDK 相比于旧的 [Ruby SDK](https://github.com/qiniu/ruby-sdk.git)，重新设计了所有 API，并拥有更强大的功能。

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

