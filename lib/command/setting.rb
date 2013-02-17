# -*- coding: UTF-8 -*-
#
# Copyright 2013 whiteleaf. All rights reserved.
#

require_relative "../localsetting"
require_relative "../globalsetting"

module Command
  class Setting < CommandBase
    def oneline_help
      "各コマンドの設定を変更します"
    end

    class InvalidVariableType < StandardError
      def initialize(type)
        super("値が #{Setting.variable_type_to_description(type).rstrip} ではありません")
      end
    end

    class UnknownVariableType < StandardError
      def initialize(type)
        super("unknwon variable type (:#{type})")
      end
    end

    class InvalidVariableName < StandardError; end

    def initialize
      super("[<name>=<value> ...] [options]")
      @opt.separator <<-EOS

  ・各コマンドの設定の変更が出来ます。
  ・Global な設定はユーザープロファイルに保存され、すべての narou コマンドで使われます。

  Local Variable List:
        <name>           <value>              説明
      EOS
      SETTING_VARIABLES[:local].each do |name, info|
        unless info[2]
          type_description = self.class.variable_type_to_description(info[0])
          @opt.separator("    #{name.ljust(18)} #{type_description} #{info[1]}")
        end
      end

      @opt.separator("\n  Global Variable List:")
      SETTING_VARIABLES[:global].each do |name, info|
        unless info[2]
          type_description = self.class.variable_type_to_description(info[0])
          @opt.separator("    #{name.ljust(18)} #{type_description} #{info[1]}")
        end
      end

      @opt.separator <<-EOS

  Example:
    narou setting --list
    narou setting convert.no-open=true
    narou setting convert.no-epub=   # 右辺に何も書かないとその設定を削除できる
    narou setting convert.copy_to=C:/dropbox/mobi
    narou s convert.copy_to="C:\\Documents and Settings\\user\\epub"

  Optioins:
      EOS
      @opt.on("-l", "--list", "現在の設定値を確認する") {
        output_setting_list
        exit 0
      }
    end

    def self.variable_type_to_description(type)
      case type
      when :boolean
        "true/false  "
      when :integer
        "整数        "
      when :string
        "文字列      "
      when :directory
        "フォルダパス"
      when :file
        "ファイルパス"
      else
        raise UnknownVariableType, type
      end
    end

    def get_scope_of_variable_name(name)
      [:local, :global].each do |scope|
        if SETTING_VARIABLES[scope].include?(name)
          return scope
        end
      end
      nil
    end

    #
    # 値の文字列を設定に基づいた型にキャストして、[scope, value] 形式で返す
    # 不正な設定名もしくは値の場合は例外を吐く
    #
    def casting_variable(name, value)
      scope = get_scope_of_variable_name(name)
      unless scope
        raise InvalidVariableName, "#{name} は不明な名前です"
      end
      casted_value = string_cast_to_type(value, SETTING_VARIABLES[scope][name][0])
      [scope, casted_value]
    end

    def string_cast_to_type(value, type)
      result = nil
      case type
      when :boolean
        case value
        when /true/i
          result = true
        when /false/i
          result = false
        else
          raise InvalidVariableType, type
        end
      when :integer
        if value =~ /^[+-]?\d+$/
          result = value.to_i
        else
          raise InvalidVariableType, type
        end
      when :directory, :file
        if File.method("#{type}?").call(value)
          result = File.expand_path(value)
        else
          raise InvalidVariableType, type
        end
      when :string
        result = value
      else
        raise UnknownVariableType, type
      end
      result
    end

    def output_setting_list
      settings = {
        local: LocalSetting.get["local_setting"],
        global: GlobalSetting.get["global_setting"]
      }
      settings.each do |scope, scoped_settings|
        puts "[#{scope.capitalize} Variables]"
        scoped_settings.each do |name, value|
          puts "#{name}=#{value}"
        end
      end
    end

    def execute(argv)
      super
      if argv.empty?
        puts @opt.help
        return
      end
      settings = {
        local: LocalSetting.get["local_setting"],
        global: GlobalSetting.get["global_setting"]
      }
      argv.each do |arg|
        name, value = arg.split("=", 2).map(&:strip)
        if name == ""
          warn "書式が間違っています。変数名=値 のように書いて下さい"
          next
        end
        scope = get_scope_of_variable_name(name)
        unless scope
          warn "#{name} という変数は存在しません"
          next
        end
        if value.nil?
          warn "書式が間違っています。#{name}=値 のように書いて下さい"
          next
        end
        if value == ""
          settings[scope].delete(name)
          puts "#{name} の設定を削除しました"
          next
        end
        begin
          scope, casted_value = casting_variable(name, value)
        rescue InvalidVariableName, InvalidVariableType => e
          warn e.message
          next
        end
        settings[scope][name] = casted_value
        puts "#{name} を #{casted_value} に設定しました"
      end
      LocalSetting.get.save_settings("local_setting")
      GlobalSetting.get.save_settings("global_setting")
    end

    SETTING_VARIABLES = {
      global: {
        # 変数名  => [受け付ける型, 説明(, 不可視化フラグ)]
        "aozoraepub3path" => [:directory, "AozoraEpub3のあるフォルダを変更"],
      },
      local: {
        "convert.no-epub" => [:boolean, "EPUB変換を無効にするかどうか"],
        "convert.no-mobi" => [:boolean, "MOBI変換を無効にするかどうか"],
        "convert.no-strip" => [:boolean, "MOBIのstripを無効にするかどうか\n" +
                                         " " * 6 + "※注意：KDP用のMOBIはstripしないでください"],
        "convert.no-open" => [:boolean, "変換終了時に保存フォルダを開かない"],
        "convert.copy_to" => [:directory, "変換したらこのフォルダにコピーする\n" +
                                          " " * 6 + "※注意：存在しないフォルダだとエラーになる"],
        "convert.inspect" => [:boolean, "常に変換時に調査結果を表示するか"],
        "download.interval" => [:integer, "各話DL時に指定した秒数待機する。デフォルト0"]
      }
    }
  end
end