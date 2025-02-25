import { useEffect, useState } from "react";
import UserTable from "../components/UserPageComponents/UserTable";

const Users = () => {
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        // Simulating data fetching
        setTimeout(() => {
            setLoading(false);
        }, 1000); // Simulate 1 second loading
    }, []);

    if (loading) {
        return <div>Loading...</div>; // Show loading state while fetching
    }

    return (
        <div className="p-5">
        <UserTable />
        </div>
    );
};

export default Users;
