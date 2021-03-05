//
//  main.cpp
//  C2
//
//  Created by Harely Huang on 2020/10/23.
//
/**
 *printf格式化输出：https://blog.csdn.net/xiexievv/article/details/6831194
 *
 */
/**
 *  #include并不是什么申请指令，只是将指定文件的内容，原封不动的拷贝进来
 *  *.h文件做的是类的声明，包括类成员的定义和函数的声明
 *  *.cpp文件做的类成员函数的具体实现（定义）
 *  在*.cpp文件的第一行一般也是#include"*.h"文件，其实也相当于把*.h文件里的东西复制到*.cpp文件的开头
 */

#include <iostream>
#include "Chapter6.hpp"





void testMethod_1();

int main(int argc, const char * argv[]) {
    
    
    Chapter6 chapter6;
    
    
    
    //chapter6.chapter6Run();
    
    //testMethod_1();
    
    system("pause");
    
    return 0;
}

void testMethod_1() {
    /*
     int val = 5;
     int *prt3 = (int *)0x1000;
     prt3 = &val;
     std::cout<<"prt3值为："<<*prt3<<"地址为："<<&prt3<<std::endl;
     std::cout<<"val值为："<<val<<"地址为："<<&val<<std::endl;
     
     */
    
    
    /*
     
     char str[30];
     std::cout<<"数组长度：30， 可接受输入长度： 10"<<std::endl;
     std::cout<<"请输入任意字符串"<<std::endl;
     
     //getline()函数进行输入，它会读取用户所输入的每个字符（包含空格符），直到用户按下【Enter】键为止。
     //getline(字符串变量， 输入长度， 字符串结束符)
     std::cin.getline(str, 10, '\n');
     
     std::cout<<"str字符串变量为："<<str<<std::endl;
     */
    
    
    
    /* 指针变量运算
     int iVal = 10;
     int *piVal = &iVal;
     
     std::cout<<"piVal指针地址原始值为："<<piVal<<std::endl;
     piVal++;
     std::cout<<"piVal++ 右移地址为："<<piVal<<std::endl;
     piVal--;
     std::cout<<"piVal-- 左移地址为："<<piVal<<std::endl;
     piVal=piVal+3;
     std::cout<<"piVal+3 向右移3个整数基本内存单元偏移量基本地址为："<<piVal<<std::endl;
     */
    
    
    /*指针变量及打印
     int num1 = 10;
     char ch1[2] = "A";
     
     std::cout<<"变量名称    变量值 内存地址"<<std::endl;
     std::cout<<"-----------------------"<<std::endl;
     
     std::cout<<"num1"<<"\t"<<num1<<"\t"<<&num1 <<std::endl;
     std::cout<<"ch1"<<"\t""\t"<<ch1<<"\t"<<&ch1 <<std::endl;
     */
    
    printf("\n\n%s","✈️ 🦊 🐱 😊 🏠 ⛽️ 💲 💶 🐂 🌟 🚀 🏆");
}






