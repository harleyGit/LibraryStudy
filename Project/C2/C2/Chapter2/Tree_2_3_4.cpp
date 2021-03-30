//
//  Tree_2_3_4.cpp
//  C2
//
//  Created by HuangGang on 2021/3/30.
//

#include "Tree_2_3_4.hpp"
#include <exception>
#include <cstdio>
using namespace std;





BinaryTreeNode* ConstructCore(int* startPreorder, int* endPreorder, int* startInorder, int* endInorder);


BinaryTreeNode* Construct(int* preorder, int* inorder, int length)
{
    if(preorder == nullptr || inorder == nullptr || length <= 0)
        return nullptr;
    
    return ConstructCore(preorder, preorder + length - 1,
                         inorder, inorder + length - 1);
}

BinaryTreeNode* ConstructCore
(
 int* startPreorder, int* endPreorder,
 int* startInorder, int* endInorder
 )
{
    // 前序遍历序列的第一个数字是根结点的值
    int rootValue = startPreorder[0];
    BinaryTreeNode* root = new BinaryTreeNode();
    root->m_nValue = rootValue;
    root->m_pLeft = root->m_pRight = nullptr;
    
    if(startPreorder == endPreorder)
    {
        if(startInorder == endInorder && *startPreorder == *startInorder)
            return root;
        else
            throw "Invalid input.";
    }
    
    // 在中序遍历中找到根结点的值
    int* rootInorder = startInorder;
    while(rootInorder <= endInorder && *rootInorder != rootValue)
        ++ rootInorder;
    
    if(rootInorder == endInorder && *rootInorder != rootValue)
        throw "Invalid input.";
    
    //左子树的长度
    int leftLength = rootInorder - startInorder;
    //左子树末尾节点位置
    int* leftPreorderEnd = startPreorder + leftLength;
    if(leftLength > 0)
    {
        // 构建左子树
        root->m_pLeft = ConstructCore(startPreorder + 1, leftPreorderEnd,
                                      startInorder, rootInorder - 1);
    }
    if(leftLength < endPreorder - startPreorder)
    {
        // 构建右子树
        root->m_pRight = ConstructCore(leftPreorderEnd + 1, endPreorder,
                                       rootInorder + 1, endInorder);
    }
    
    return root;
}

