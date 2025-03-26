#include <frc/TimedRobot.h>
#include <iostream>

class Robot : public frc::TimedRobot {
public:
	void RobotInit() {
		std::cout << "Test" << std::endl;
	}
};

int main() {
	frc::StartRobot<Robot>();
	return 0;
}
