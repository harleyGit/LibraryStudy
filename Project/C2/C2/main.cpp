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


#include <iostream>
#include "Chapter6.hpp"
#include "SortExercise.hpp"
#include "DFSExercise.hpp"

void testMethod_1();
void testQuickSort();
void testDFSExerice();

int main(int argc, const char * argv[]) {
    
    //testMethod_1();
    
    //快速排序
    //testQuickSort();

    testDFSExerice();
    
    printf("\n\n\n");
    system("pause");
    
    return 0;
}




//使用 DFS 暴力搜索，过程中进行剪枝
void testDFSExerice() {
//    int jobs[] = {254,256,256,254,251,256,254,253,255,251,251,255};// n = 12
//    int k = 10;
//
//    int jobs[] = {1,2,4,7,8}; //n=5
//    int k = 2;//工作时间 11；
    
    
    int jobs[] = {3,2,3}; //n=3
    int k = 3;//工作时间 11；
    
    int length = sizeof(jobs)/sizeof(int);
    //通过数组a的地址初始化，注意地址是从0到5（左闭右开区间）
    vector<int> vecJobs(jobs, jobs+length);
    DFSExercise testDFSExercise;
    int a = testDFSExercise.minimumTimeRequired(vecJobs, k);
    
    PrintFormat2("完成所有工作的最短时间: %i", a);
}


//快速排序
void testQuickSort() {
    //int a[] = {900, 2, -58, 3, 34, 5, 76, 7, 32, 4, 43, 9, 1, 56, 8,-70, 635, -234, 532, 543, 2500};
    SortExercise testSortExercise;
    int a[] = {100, 20, 60, -20, 200};
    int length = sizeof(a) / sizeof(int);
    testSortExercise.quickSort(a, 0, length - 1);
    
    for (int i = 0; i < length ; i++) {
        printf("%d ", a[i]);
    }
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






