//
//  Chapter6.hpp
//  C2
//
//  Created by Harely Huang on 2020/10/28.
//

#ifndef Chapter6_hpp
#define Chapter6_hpp
#include <stdio.h>

/**
 *打印格式1
 */
#define PrintFormat1(format, ...) \
printf("🍎 🍎 🍎 🍎"\
"\n"\
"文件名: %s"\
"\n"\
"ANSI标准: %d 时间：%s %s  行数: %d 函数:%s \n"\
"参数值：" format "\n", __FILE__, __STDC__, __DATE__, __TIME__,  __LINE__, __FUNCTION__, ##__VA_ARGS__)

/**
 *打印格式2
 */
#define PrintFormat2(format, ...) \
printf("\n🍎 🍎 🍎 🍎\n%d %s %s,  %s[%d]: " format "\n" "🍊 🍊 🍊 🍊\n\n", __STDC__, __DATE__, __TIME__, __FUNCTION__, __LINE__,  ##__VA_ARGS__)




class Chapter6 {
    
public:
    //二叉树结构体
    typedef struct BinaryTree {
        char value;
        struct BinaryTree *leftChild;
        struct BinaryTree *rightChild;
    }BinaryTree, *BinaryTreeNode;
    //二叉树输入值
    //    char characters[16] = "52##4##36##8##7";
    //    char characters[24] = "ABDH#K###E##CFI###G#J##";
    char characters[10] = "AB#D##C##";
    //起始变量值
    int number = 0;
    
    
    
    
    
    
    /// 二叉树创建
    /// @param binaryTree 根结点指针
    void createBinaryTree(BinaryTreeNode *binaryTree, int index = 0);
    
    
};



#endif /* Chapter6_hpp */
