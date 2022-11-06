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
#include <cstdlib>
#include <vector>//头文件一定要有
#include <string.h>
#include "Chapter6.hpp"
#include "SortExercise.hpp"
#include "DFSExercise.hpp"

using namespace std;//其所在的命名空间


void testMethod_1();
void testQuickSort();
void testDFSExerice();

//十大排序算法
int* bubbleSort(char methodName[],int array[], int length);
int* selectSort(char methodName[], int array[], int length);
int* insertionSort(char methodName[], int array[], int length);
void quickSort(vector<int> &array, int left, int right);





int main(int argc, const char * argv[]) {
    
    
    
    
    //        快速排序
    //    vector<int> vec1{9,0,6,5,8,2,1,7,4,3};
    //    quickSort(vec1, 0, vec1.size()-1);
    //    printf("=================快速排序=================\n");
    //    for (int i = 0; i < vec1.size(); i++) {
    //        printf("%i ", vec1[i]);
    //    }
    
    //        插入排序
    //    int a[] = {9,0,6,5,8,2,1,7,4,3};
    //    char methodName[] = "插入排序";
    //    int *b = insertionSort(methodName,a, 10);
    //    for (int i=0; i< 10; i++) {
    //        printf("%i ", *(b+i));
    //    }
    
    
    //    testMethod_1();
    
    //    快速排序
    //    testQuickSort();
    
    //    冒泡排序
    //    int a[] = {9,0,6,5,8,2,1,7,4,3};
    //    char methodName[] = "冒泡排序";
    //    int *b = bubbleSort(methodName,a, 10);
    //    for (int i=0; i< 10; i++) {
    //        printf("%i ", *(b+i));
    //    }
    
    
    //    选择排序
    //    int a[] = { 3,  5,  2,  9,  7,  8,  4,  1,  6,  10 };//{9,0,6,5,8,2,1,7,4,3};
    //    char methodName[] = "选择排序";
    //    int *b = bubbleSort(methodName,a, 10);
    //    for (int i=0; i< 10; i++) {
    //        printf("%i ", *(b+i));
    //    }
    
    //testDFSExerice();
    
    printf("\n\n\n");
    system("pause");
    
    return 0;
}




//快速排序
void quickSort(vector<int> &array, int left, int right){
    
    //为了后来获取到的元素索引j比i小，所以减去1
    int j = left -1;
    for (int i = left; i < right; ++i) {//{9,0,6,5,8,2,1,7,4,3}
        
        //数组的最后一位总比数组元素的前面大时，对其前面的元素进行排序，小的在前面，大的在后面除了最后一个元素没有交换位置
        if (array[i] <= array[right]) {
            ++j;
            
            //比如：i= 0时,j=2，是a[0]和a[2]交换。这时最小值a[2]在最前面了
            int a = array[i];
            array[i] = array[j];
            array[j] = a;
        }
    }
    
    //对array的j+1位和数组元素的最后right索引进行替换，因为array[j+1] >= array[right]
    int c = array[j+1];
    array[j+1] = array[right];
    array[right] = c;
    
    
    if (left < right) {
        quickSort(array, left, j);
        quickSort(array, j+1, right);
    }
    
}


//插入排序
int* insertionSort(char methodName[], int array[], int length) {
    printf("=================%s=================\n", methodName);
    
    for (int i = 0, j, temp; i < length -1; i ++) {
        
        j = i;
        temp = *(array+i+1);//{9,0,6,5,8,2,1,7,4,3}
        
        //作用：1.用来比较前后2个元素的大小，当后面的比前面的大时就调换位置；
        //2.遇到最前面的元素小于temp时，跳出这个while循环
        while (j >= 0 && array[j] > temp) {
            array[j+1] = array[j]; //第一次时array[j+1]是最大的，但是随着j越来越小array[j+1]不是最大的了，如：j第一次为5，后来变成了4，3，2，1分别越来越对应最初的元素了{0,6,9
            --j;
        }
        //把要插入的值插入进去，因为在上面j已经减去1了，所以这里面j要加1
        array[j+1] = temp;
    }
    return  array;
}

//选择排序
int* selectSort(char methodName[], int array[], int length){
    
    for (int i = 0; i < (length-1); i ++) {//需要循环的次数
        for (int k = 0; k < (length - i); k++) {//按照从小往大的排，末尾的是排好的，所以前面还有（length-i）个没有排好
            if (*(array+k)>*(array+k+1)) {
                int a = *(array+k);
                *(array+k) = *(array+k+1);
                *(array+k+1) = a;
            }
        }
    }
    
    return  array;
}


//冒泡排序
int* bubbleSort(char methodName[],int array[], int length){
    printf("=================%s=================\n", methodName);
    
    for (int i = 0; i < (length - 1); i ++) {
        for (int k = 0; k < length - 1 - i; k ++) {
            if (array[k] <= array[k+1]) {
                continue;
            }else {
                int a = 0;
                a = array[k];
                array[k] = array[k+1];
                array[k+1] = a;
                /*
                 swap((array+k), (array+k+1));
                 
                 void swap(int *a, int *b){
                 int c = *a;
                 *a = *b;
                 *b = c;
                 
                 }
                 */
            }
            
        }
    }
    printf("\n");
    
    return array;
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






