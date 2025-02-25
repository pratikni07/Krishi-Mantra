import React, { useState, useEffect, useMemo, useCallback } from "react";
import {
  Table,
  TableHeader,
  TableColumn,
  TableBody,
  TableRow,
  TableCell,
  Input,
  Button,
  DropdownTrigger,
  Dropdown,
  DropdownMenu,
  DropdownItem,
  Chip,
  User,
  Pagination,
  Spinner,
  Modal,
  ModalContent,
  ModalHeader,
  ModalBody,
  ModalFooter,
  useDisclosure
} from "@nextui-org/react";
import { apiConnector } from "../../service/apiconnector";
import { usersendpoints } from "../../service/apis";
// Icons
const SearchIcon = (props) => (
  <svg
    aria-hidden="true"
    fill="none"
    focusable="false"
    height="1em"
    role="presentation"
    viewBox="0 0 24 24"
    width="1em"
    {...props}
  >
    <path
      d="M11.5 21C16.7467 21 21 16.7467 21 11.5C21 6.25329 16.7467 2 11.5 2C6.25329 2 2 6.25329 2 11.5C2 16.7467 6.25329 21 11.5 21Z"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="2"
    />
    <path
      d="M22 22L20 20"
      stroke="currentColor"
      strokeLinecap="round"
      strokeLinejoin="round"
      strokeWidth="2"
    />
  </svg>
);

const VerticalDotsIcon = (props) => (
  <svg
    aria-hidden="true"
    fill="none"
    focusable="false"
    height="24"
    role="presentation"
    viewBox="0 0 24 24"
    width="24"
    {...props}
  >
    <path
      d="M12 10c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0-6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 12c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"
      fill="currentColor"
    />
  </svg>
);

// Columns Configuration
const columns = [
  { name: "NAME", uid: "name", sortable: true },
  { name: "EMAIL", uid: "email", sortable: true },
  { name: "PHONE", uid: "phoneNo", sortable: true },
  { name: "ACCOUNT TYPE", uid: "accountType", sortable: true },
  { name: "ACTIONS", uid: "actions" }
];

// Account Type Color Mapping
const accountTypeColorMap = {
  admin: "success",
  user: "default",
  premium: "secondary"
};

export default function UserTable() {
  // State Management
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filterValue, setFilterValue] = useState("");
  const [page, setPage] = useState(1);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const [selectedUser, setSelectedUser] = useState(null);
  const { isOpen, onOpen, onOpenChange } = useDisclosure();

  const [sortDescriptor, setSortDescriptor] = useState({
    column: "name",
    direction: "ascending"
  });

  // Pagination State
  const [pagination, setPagination] = useState({
    currentPage: 1,
    totalPages: 1,
    totalUsers: 0,
    hasNextPage: false,
    hasPreviousPage: false
  });

  // Fetch Users
  const fetchUsers = async (currentPage = 1, limit = rowsPerPage) => {
    try {
      setLoading(true);
      const { GET_ALL_USER_API } = usersendpoints;
      const response = await apiConnector(
        "GET", 
        `${GET_ALL_USER_API}?page=${currentPage}&limit=${limit}`
      );
      console.log(response)

      if (response?.data) {
        setUsers(response.data.users);
        setPagination(response.data.pagination);
      }
    } catch (error) {
      console.error("Error fetching users:", error);
    } finally {
      setLoading(false);
    }
  };

  // Initial Data Fetch
  useEffect(() => {
    fetchUsers();
  }, []);

    // View User Details Handler
    const handleViewDetails = useCallback((user) => {
        setSelectedUser(user);
        onOpen();
      }, [onOpen]);


  // Filtering Logic
  const filteredItems = useMemo(() => {
    let result = [...users];
    
    if (filterValue) {
      result = result.filter(
        (user) => 
          user.name.toLowerCase().includes(filterValue.toLowerCase()) ||
          user.email.toLowerCase().includes(filterValue.toLowerCase())
      );
    }

    return result;
  }, [users, filterValue]);

  // Sorting Logic
  const sortedItems = useMemo(() => {
    return [...filteredItems].sort((a, b) => {
      const first = a[sortDescriptor.column];
      const second = b[sortDescriptor.column];
      const cmp = first < second ? -1 : first > second ? 1 : 0;
      return sortDescriptor.direction === "descending" ? -cmp : cmp;
    });
  }, [filteredItems, sortDescriptor]);

  // Render Cell Content
  const renderCell = useCallback((user, columnKey) => {
    switch (columnKey) {
      case "name":
        return (
          <User
            avatarProps={{
              radius: "full",
              size: "sm",
              src: user.image || "/default-avatar.png"
            }}
            name={user.name}
            description={user.email}
          >
            {user.name}
          </User>
        );
      
      case "accountType":
        return (
          <Chip
            className="capitalize"
            color={accountTypeColorMap[user.accountType]}
            size="sm"
            variant="dot"
          >
            {user.accountType}
          </Chip>
        );
      
      case "actions":
        return (
          <div className="relative flex justify-end items-center gap-2">
            <Dropdown>
              <DropdownTrigger>
                <Button isIconOnly size="sm" variant="light">
                  <VerticalDotsIcon />
                </Button>
              </DropdownTrigger>
              <DropdownMenu>
                <DropdownItem 
                  key="view" 
                  onPress={() => handleViewDetails(user)}
                >
                  View Details
                </DropdownItem>
                <DropdownItem key="edit">Edit User</DropdownItem>
              </DropdownMenu>
            </Dropdown>
          </div>
        );
      
      default:
        return user[columnKey];
    }
  }, [handleViewDetails]);

  const UserDetailsModal = () => {
    if (!selectedUser) return null;

    return (
      <Modal 
        isOpen={isOpen} 
        onOpenChange={onOpenChange}
        size="2xl"
        scrollBehavior="inside"
      >
        <ModalContent>
          {(onClose) => (
            <>
              <ModalHeader className="flex flex-col gap-1">
                User Details
              </ModalHeader>
              <ModalBody>
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <p className="font-bold">Basic Information</p>
                    <div className="space-y-2 mt-2">
                      <p><strong>Name:</strong> {selectedUser.name}</p>
                      <p><strong>First Name:</strong> {selectedUser.firstName}</p>
                      <p><strong>Last Name:</strong> {selectedUser.lastName}</p>
                      <p><strong>Email:</strong> {selectedUser.email}</p>
                      <p><strong>Phone:</strong> {selectedUser.phoneNo}</p>
                    </div>
                  </div>

                  <div>
                    <p className="font-bold">Account Details</p>
                    <div className="space-y-2 mt-2">
                      <p><strong>Account Type:</strong> {selectedUser.accountType}</p>
                      <p><strong>Created At:</strong> {new Date(selectedUser.createdAt).toLocaleString()}</p>
                      <p><strong>Updated At:</strong> {new Date(selectedUser.updatedAt).toLocaleString()}</p>
                    </div>
                  </div>

                  <div className="col-span-2">
                    <p className="font-bold">Additional Details</p>
                    <div className="space-y-2 mt-2">
                      <p><strong>Subscription:</strong> {selectedUser.additionalDetails?.subscription?.type?.type || 'N/A'}</p>
                      <p><strong>Location:</strong> 
                        Latitude: {selectedUser.additionalDetails?.location?.latitude}, 
                        Longitude: {selectedUser.additionalDetails?.location?.longitude}
                      </p>
                      <p><strong>Address:</strong> {selectedUser.additionalDetails?.address || 'N/A'}</p>
                    </div>
                  </div>
                </div>
              </ModalBody>
              <ModalFooter>
                <Button color="danger" variant="light" onPress={onClose}>
                  Close
                </Button>
              </ModalFooter>
            </>
          )}
        </ModalContent>
      </Modal>
    );
  };


  // Top Content (Search and Filters)
  const topContent = useMemo(() => (
    <div className="flex flex-col gap-4">
      <div className="flex justify-between gap-3 items-end">
        <Input
          isClearable
          className="w-full sm:max-w-[44%]"
          placeholder="Search by name or email..."
          startContent={<SearchIcon />}
          value={filterValue}
          onClear={() => setFilterValue("")}
          onValueChange={setFilterValue}
        />
        <div className="flex gap-3">
          <Button color="primary" variant="solid">
            Add New User
          </Button>
        </div>
      </div>
    </div>
  ), [filterValue]);

  // Bottom Content (Pagination)
  const bottomContent = useMemo(() => (
    <div className="py-2 px-2 flex justify-between items-center">
      <Pagination
        isCompact
        showControls
        showShadow
        color="primary"
        page={pagination.currentPage}
        total={pagination.totalPages}
        onChange={(page) => fetchUsers(page)}
      />
      <div className="hidden sm:flex w-[30%] justify-end gap-2">
        <span>Total Users: {pagination.totalUsers}</span>
      </div>
    </div>
  ), [pagination]);

  return (
    <>
        <Table
        aria-label="Users Table"
        isHeaderSticky
        bottomContent={bottomContent}
        bottomContentPlacement="outside"
        topContent={topContent}
        topContentPlacement="outside"
        sortDescriptor={sortDescriptor}
        onSortChange={setSortDescriptor}
        >
        <TableHeader columns={columns}>
            {(column) => (
            <TableColumn 
                key={column.uid} 
                allowsSorting={column.sortable}
            >
                {column.name}
            </TableColumn>
            )}
        </TableHeader>
        <TableBody 
            items={sortedItems} 
            emptyContent="No users found"
            isLoading={loading}
            loadingContent={<Spinner label="Loading users..." />}
        >
            {(item) => (
            <TableRow key={item._id}>
                {(columnKey) => (
                <TableCell>{renderCell(item, columnKey)}</TableCell>
                )}
            </TableRow>
            )}
        </TableBody>
        </Table>
        <UserDetailsModal/>
    </>
  );
}