# LibraryStudy
**优秀三方库学习**

- **终端代理设置**
- [**AFNetworking**](https://juejin.cn/post/6844903825581555726)
- **Project**

<br/>

***
<br/>

>#	 终端代理设置

-	两个命令可以查看当前的http、https代理

```diff
//查询代理
-	echo $http_proxy	check http proxy
//查询代理
!	echo $https_proxy	check https proxy
//设置代理
+	export http_proxy=http://ip:port	set http proxy
//设置代理
-	export https_proxy=https://ip:port	set https proxy
+	export ALL_proxy=http://ip:port	set http&https proxy
//编辑.bash_profile的文件内容，设置https/http代理
!	vim ~/.bash_profile	edit Mac proxy file
-	source ~/.bash_profile	save .bash_profile settings
+	cat ~/.bash_profile	use .bash_profile settings
```

-	代理设置

```
export http_proxy=http://代理ip:端口

export https_proxy=http://代理ip:端口
```



<br/>

***
<br/>

># AFNetworking




<br/>

***
<br/>

># Project
优秀项目代码的学习借鉴

- 仿喜马拉雅
- C2: C和C++代码练习
- FlutterDeer： Flutter项目代码学习借鉴
- headlineNews
- SwiftEOS: 加密库练习
- SwiftHub： 国外大神借助RxSwift的优秀代码项目
- [MHDevelopExample](https://www.jianshu.com/p/db8400e1d40e)：优秀设计模式Demo









