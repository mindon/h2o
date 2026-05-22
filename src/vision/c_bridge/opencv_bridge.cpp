#include <opencv2/opencv.hpp>
#include <vector>

extern "C" {
    typedef struct {
        float area;
        float perimeter;
        float width;
        float height;
    } SpotData;

    SpotData analyze_image_opencv(const char* image_path) {
        SpotData data = {0, 0, 0, 0};

        // 安全检查：路径有效性
        if (!image_path || image_path[0] == '\0') {
            return data;
        }

        cv::Mat image = cv::imread(image_path);
        if (image.empty()) {
            // 图像读取失败，返回零值而非崩溃
            return data;
        }

        cv::Mat gray, thresh;
        cv::cvtColor(image, gray, cv::COLOR_BGR2GRAY);

        // 自适应阈值 — 比固定阈值更鲁棒
        cv::adaptiveThreshold(gray, thresh, 255, 
            cv::ADAPTIVE_THRESH_GAUSSIAN_C, cv::THRESH_BINARY_INV, 11, 2);
        
        std::vector<std::vector<cv::Point>> contours;
        cv::findContours(thresh, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);
        
        if (contours.empty()) {
            return data;
        }

        // 取面积最大的轮廓（而非第一个轮廓）
        size_t max_idx = 0;
        double max_area = 0;
        for (size_t i = 0; i < contours.size(); i++) {
            double a = cv::contourArea(contours[i]);
            if (a > max_area) {
                max_area = a;
                max_idx = i;
            }
        }
        
        double perimeter = cv::arcLength(contours[max_idx], true);
        cv::Rect rect = cv::boundingRect(contours[max_idx]);
        
        data.area = (float)max_area;
        data.perimeter = (float)perimeter;
        data.width = (float)rect.width;
        data.height = (float)rect.height;

        return data;
    }
}
