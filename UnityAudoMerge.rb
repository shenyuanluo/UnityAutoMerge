#!/usr/bin/ruby
# Author: ShenYuanLuo
# Site: http://blog.shenyuanluo.com/
# Date: 2020-05-08

require 'Xcodeproj'

# 《============================ 请使用绝对路径配置一下参数 ============================ 》
# Unity 资源文件夹（即：Unity 工程中 'Classes'、'Libraries'、'Data' 所在的目录绝对路径，不支持当前用户路径：'~'）
source_dir = "Your_Unity_Project_Folder_Absolute_Path"
# iOS_Unity 目的文件夹（即：iOS 工程中 Unity 对应的 'Classes'、'Libraries'、'Data' 所在的目录绝对路径，不支持当前用户路径：'~'）
dest_dir = "Your_iOS_Project_Unity_Source_Folder_Absolute_Path"
# iOS 工程根目录（即：iOS 工程 '***.xcodeproj' 所在目录绝对路径）
root_path = "Your_iOS_Project_Folder_Absolute_Path"
# iOS 工程文件名（即：iOS 工程 '***.xcodeproj' 文件名）
project_file_name = "***.xcodeproj"



# Unity 合并处理类
class UnityMergeHandler
    
    # 终端宽度
    @@terminal_width  = `stty size|cut -d' ' -f2`.to_i
    # 终端高度
    @@terminal_height = `stty size|cut -d' ' -f1`.to_i
    # 进度条
    @@bar_header = 'Progress bar: '
    @@bar_length = @@terminal_width -  2 * @@bar_header.length
    
    # 条件子串
    @@condition_str = "Classes/Native"
    # 工程对象
    @project
    # 生产目标
    @target
    # 组
    @group
    
    # 新增文件数组
    @add_file_array
    # 新增文件夹数组
    @add_foloder_array
    # 删除文件数组
    @del_file_array
    # 删除文件夹数组
    @del_folder_array
    
    # 文件总数
    @all_file_count
    # 当前处理文件数
    @cur_file_count
    # 开始处理时间
    @start_handle_time_s
    # 结束处理时间
    @end_handle_time_s
    
    
    # 构造函数
    def initialize(source_dir, dest_dir, root_path, project_name)
        
        @add_file_array    = Array.new
        @add_foloder_array = Array.new
        @del_file_array    = Array.new
        @del_folder_array  = Array.new
        @all_file_count   = 0
        @cur_file_count   = 0
        @source_dir_path = source_dir
        @dest_dir_path   = dest_dir
        
        @project_root_path = root_path      # 工程根目录
        @project_file_name = project_name   # 工程文件名
        @project_file_path = File.join(@project_root_path, @project_file_name)  # 工程文件路径
        # 打开工程文件
        @project = Xcodeproj::Project.open(@project_file_path)
        # 获取 target
        @target = @project.targets.first
        # 构建 Group
        @group = @project.main_group.find_subpath('Unity/Classes/Native', true)
    end

    
    # 文字着色（着色文字，色码）
    def colorize(text, color_code)
        "\e[#{color_code}m#{text}\e[0m"
    end
    
    
    # 红色字体
    def red(text)
        colorize(text, 31)
    end
    
    
    # 绿色字体
    def green(text)
        colorize(text, 32)
    end
    
    
    # 进度百分比显示
    def progress_percentage(curIdx, totalIdx)
        per     = curIdx * @@bar_length / totalIdx
        remain  = @@bar_length - per
        percent = curIdx * 100 / totalIdx  # 进度百分比
        printf("\r\e[#{@@terminal_height};0H#{@@bar_header} \e[42m%#{per}s\e[47m%#{remain}s\e[00m %s%%", "", "", percent)
    end
              
              
    # 递归计算文件个数
    def rec_calculate_file_count(file_path)
        Dir.foreach(file_path) do |file_name|
            # 资源文件夹过滤
            if file_path == @source_dir_path    # 顶层文件夹过滤
                if file_name != "Classes" and file_name != "Data" and file_name != "Libraries"
                    next
                end
            end
            # Classes/Native 文件夹过滤
            if file_path == @source_dir_path + "/Classes"
                if file_name != "Native"
                    next
                end
            end
            # 系统‘隐藏’文件过滤
            if file_name == "." or file_name == ".." or file_name == ".DS_Store"
                next
            end
            
            if File.directory? (file_path + "/" + file_name)        # 如果是‘文件夹’
                # 递归处理
                rec_calculate_file_count(file_path + "/" + file_name)
            elsif File.file? (file_path + "/" + file_name)    # 如果是‘文件’
                @all_file_count += 1
            end
        end
    end
               
               
    # 递归删除文件（并记录文件路径）
    def rec_delete_file(file_path)
        Dir.foreach(file_path) do |file_name|
            # 系统‘隐藏’文件过滤
            if file_name == "." or file_name == ".."
                next
            end
            if File.directory? (file_path + "/" + file_name)    # 如果是'文件夹'
                # 递归处理
                rec_delete_file(file_path + "/" + file_name)
            elsif File.file? (file_path + "/" + file_name)   # 如果是'文件'
                File.delete(file_path + "/" + file_name)  # 删除文件
                if file_name != ".DS_Store"
                    @del_file_array.push(file_path + "/" + file_name) # 记录‘删除’文件
                    @cur_file_count += 1
                    progress_percentage(@cur_file_count, @all_file_count)
                end
            end
        end
        
        @del_folder_array.push(file_path)   # 记录‘删除’文件夹
        Dir.delete(file_path)   # 记录‘删除’文件夹
    end
    
    
    # 递归检查‘新增’文件
    def rec_check_add_file(src_file_path, dest_file_path)
        Dir.foreach(src_file_path) do |file_name|
            # 系统‘隐藏’文件过滤
            if file_name == "." or file_name == ".." or file_name == ".DS_Store"
                next
            end
            # 资源文件夹过滤
            if src_file_path == @source_dir_path    # 顶层文件夹过滤
                if file_name != "Classes" and file_name != "Data" and file_name != "Libraries"
                    next
                end
            end
            # Classes/Native 文件夹过滤
            if src_file_path == @source_dir_path + "/Classes"
                if file_name != "Native"
                    next
                end
            end
            
            if File.directory? (src_file_path + "/" + file_name)  # 如果是‘文件夹’
                unless File.exist? (dest_file_path + "/" + file_name)   # 如果文件夹不存在
                    @add_foloder_array.push(dest_file_path + "/" + file_name)   # 记录‘新增’文件夹
                    Dir.mkdir(dest_file_path + "/" + file_name) # 创建文件夹
                end
                # 递归处理
                rec_check_add_file(src_file_path + "/" + file_name, dest_file_path + "/" + file_name)
            elsif File.file? (src_file_path + "/" + file_name)    # 如果是‘文件’
                unless File.exist? (dest_file_path + "/" + file_name) # 文件不存在
                    @add_file_array.push(dest_file_path + "/" + file_name)  # 记录‘新增’文件
                end
                FileUtils.cp(src_file_path + "/" + file_name, dest_file_path + "/" + file_name) # 拷贝到目标路径
                # 计算进度
                @cur_file_count += 1
                progress_percentage(@cur_file_count, @all_file_count)
            end
        end
    end
    
    
    # 递归检查‘删除’文件
    def rec_check_del_file(src_file_path, dest_file_path)
        Dir.foreach(src_file_path) do |file_name|
            # 系统‘隐藏’文件过滤
            if file_name == "." or file_name == ".." or file_name == ".DS_Store"
                next
            end
            
            if File.directory? (src_file_path + "/" + file_name)  # 如果是‘文件夹’
                if File.exist? (dest_file_path + "/" + file_name)   # 如果文件夹存在
                    # 递归处理
                    rec_check_del_file(src_file_path + "/" + file_name, dest_file_path + "/" + file_name)
                else
                    rec_delete_file(src_file_path + "/" + file_name)   # 则递归删除文件夹下的文件
                end
            elsif File.file? (src_file_path + "/" + file_name)    # 如果是‘文件’
                unless File.exist? (dest_file_path + "/" + file_name) # 文件不存在
                    @del_file_array.push(src_file_path + "/" + file_name)  # 记录‘删除’文件
                    File.delete(src_file_path + "/" + file_name)   # 删除源文件
                end
                # 计算进度
                @cur_file_count += 1
                progress_percentage(@cur_file_count, @all_file_count)
            end
        end
    end
    
    
    # 添加文件依赖
    def add_reference(target, project, to_group, file_path, need_mrc)
        if to_group and File::exist?(file_path)
            if file_path != "." and file_path != ".." and file_path != ".DS_Store"
                pb_gen_file_path = file_path
                if to_group.find_file_by_path(pb_gen_file_path)
                    puts pb_gen_file_path + " reference exist"
                else
                    file_reference = to_group.new_reference(pb_gen_file_path)
                    if need_mrc and file_path.include?("pbobjc.m")
                        target.add_file_references([file_reference],'-fno-objc-arc')
                    else
                        target.add_file_references([file_reference])
                    end
                end
            end
            project.save
        end
    end
    
    
    # 移除文件依赖
    def rmv_reference(target, project, from_group, file_path)
        if from_group and file_path
            from_group.files.each do |file_ref|
                if file_ref.real_path.to_s == file_path
                    file_ref.remove_from_project
                    target.source_build_phase.remove_file_reference(file_ref)
                    target.resources_build_phase.remove_file_reference(file_ref)
                    target.headers_build_phase.remove_file_reference(file_ref)
                    break
                end
            end
            project.save
        end
    end
    
               
    # 开始处理
    def start_handle
        puts "开始处理，耐心等待。。。"
        
        # 起始处理时间
        @start_handle_time_s = Time.now
        
        # 计算文件总数
        rec_calculate_file_count(@source_dir_path)
        rec_calculate_file_count(@dest_dir_path)
        
        # 递归解析(新增文件)
        rec_check_add_file(@source_dir_path, @dest_dir_path)
        # 新增文件-累加
        @all_file_count += 2 * @add_file_array.length
        # 递归解析(删除文件)
        rec_check_del_file(@dest_dir_path, @source_dir_path)
        # 删除文件-累加
        @all_file_count += @del_file_array.length
        
        
        # 添加‘新增’的文件依赖
        @add_file_array.length.times do |idx|
            add_file_path = @add_file_array[idx]
            if add_file_path.include? (@@condition_str) and File.exist? (add_file_path)
                add_reference(@target, @project, @group, add_file_path, false) # 添加依赖
            end
            @cur_file_count += 1
            progress_percentage(@cur_file_count, @all_file_count)
        end

        # 移除‘删除’的文件依赖
        @del_file_array.length.times do |idx|
            rmv_file_path = @del_file_array[idx]
            if rmv_file_path.include? (@@condition_str)
                rmv_reference(@target, @project, @group, rmv_file_path) # 移除依赖
            end
            @cur_file_count += 1
            progress_percentage(@cur_file_count, @all_file_count)
        end
       
       
        puts ""
       # 遍历新增的文件数组
       @add_file_array.length.times do |idx|
            puts "\e[42;37m新增文件：\e[00m" + green("#{@add_file_array[idx]}")
       end
       
       # 遍历新增的文件夹数组
       @add_foloder_array.length.times do |idx|
           puts "\e[42;37m新增文件夹：\e[00m" + green("#{@add_foloder_array[idx]}")
       end

       # 遍遍历不存在的文件数组
       @del_file_array.length.times do |idx|
            puts "\e[41;37m删除文件：\e[00m" + red("#{@del_file_array[idx]}")
       end

       # 遍历不存在的文件夹数组
       @del_folder_array.length.times do |idx|
           puts "\e[41;37m删除文件夹：\e[00m" + red("#{@del_folder_array[idx]}")
       end
       
       
        # 结束处理时间
        @end_handle_time_s = Time.now
        duration = @end_handle_time_s - @start_handle_time_s
        
        puts "\e[43;37m处理完毕\e[00m（耗时：" + green(duration) + " 秒）"
    end
end


# 开始执行
merge = UnityMergeHandler.new(source_dir, dest_dir, root_path, project_file_name)
merge.start_handle()

